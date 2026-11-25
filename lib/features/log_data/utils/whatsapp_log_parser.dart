import 'dart:core';

class ParsedWhatsAppLog {
  final DateTime? date;
  final List<String> team;
  final List<String> items;
  final String equipmentOrArea;
  final String category;
  final String? pendingFollowUp;
  final String status; // 'completed' or 'pending'
  final String cleanDescription;

  ParsedWhatsAppLog({
    this.date,
    this.team = const [],
    this.items = const [],
    this.equipmentOrArea = '',
    this.category = 'General Maintenance',
    this.pendingFollowUp,
    this.status = 'completed',
    this.cleanDescription = '',
  });
}

class WhatsAppLogParser {
  /// Parse raw unformatted WhatsApp message into structured General Work Log
  static ParsedWhatsAppLog parse(String text) {
    if (text.trim().isEmpty) return ParsedWhatsAppLog();

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    DateTime? detectedDate;
    List<String> detectedTeam = [];
    final List<String> detectedItems = [];
    final List<String> pendingNotes = [];
    final Set<String> areaSet = {};

    // 1. Regex for Dates (supports DD.MM.YYYY, DD.MM.YY, DD-MM-YYYY, DD/MM/YYYY, with optional prefixes)
    final dateReg = RegExp(
      r'(?:date\s*[:\-\–]?\s*)?(\b\d{1,2})[\.\-\/](\d{1,2})[\.\-\/](\d{2,4})\b',
      caseSensitive: false,
    );

    // 2. Identify and extract Date
    int firstContentLineIdx = 0;
    for (int i = 0; i < lines.length && i < 4; i++) {
      final match = dateReg.firstMatch(lines[i]);
      if (match != null) {
        final day = int.tryParse(match.group(1)!) ?? 1;
        final month = int.tryParse(match.group(2)!) ?? 1;
        var year = int.tryParse(match.group(3)!) ?? DateTime.now().year;
        if (year < 100) year += 2000;
        try {
          detectedDate = DateTime(year, month, day);
        } catch (_) {}
        // If line is ONLY the date (or date with title), advance content index
        if (lines[i].replaceAll(match.group(0)!, '').trim().length < 4) {
          firstContentLineIdx = i + 1;
        }
        break;
      }
    }

    // 3. Identify and extract Team / Technicians
    final teamKeywords = RegExp(r'\b(team|members|shift|duty|crew)\s*[:\-\–]', caseSensitive: false);
    for (int i = firstContentLineIdx; i < lines.length && i < firstContentLineIdx + 4; i++) {
      final line = lines[i];
      final isTeamLabeled = teamKeywords.hasMatch(line);
      final hasPlus = line.contains('+');
      final hasNamesComma = line.split(',').length >= 2 && !line.toLowerCase().contains('was') && !line.toLowerCase().contains('were') && !line.toLowerCase().contains('completed');

      if (isTeamLabeled || hasPlus || hasNamesComma) {
        String cleaned = line.replaceAll(RegExp(r'[\*\#_]'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\bteam\s*[:\-\–]', caseSensitive: false), '');
        cleaned = cleaned.replaceAll(RegExp(r'\(shm jobs\)', caseSensitive: false), '');
        cleaned = cleaned.replaceAll(RegExp(r'in between\.?', caseSensitive: false), '');
        cleaned = cleaned.replaceAll(RegExp(r'\bhalf day\.?', caseSensitive: false), '');
        cleaned = cleaned.replaceAll(RegExp(r'\b\+?\s*\d+\s*appr\.?', caseSensitive: false), '');

        final members = cleaned
            .split(RegExp(r'[,+\&]|\band\b', caseSensitive: false))
            .map((m) => m.trim())
            .where((m) => m.isNotEmpty && m.length > 1 && !RegExp(r'^\d+$').hasMatch(m))
            .toList();

        if (members.isNotEmpty) {
          detectedTeam = members;
          firstContentLineIdx = i + 1;
          break;
        }
      }
    }

    // Fallback: If still no team detected, check if first line looks like a name list
    if (detectedTeam.isEmpty && firstContentLineIdx < lines.length) {
      final line = lines[firstContentLineIdx];
      if (line.split(' ').length <= 8 &&
          !line.toLowerCase().contains('completed') &&
          !line.toLowerCase().contains('replaced') &&
          !line.toLowerCase().contains('was') &&
          (line.contains('+') || line.contains(',') || line.toUpperCase() == line)) {
        String cleaned = line.replaceAll(RegExp(r'[\*\#_]'), '');
        final members = cleaned
            .split(RegExp(r'[,+\&]|\band\b', caseSensitive: false))
            .map((m) => m.trim())
            .where((m) => m.isNotEmpty && m.length > 2 && !m.toLowerCase().contains('in between'))
            .toList();
        if (members.length >= 2) {
          detectedTeam = members;
          firstContentLineIdx++;
        }
      }
    }

    // 4. Extract Tasks & Work Items
    final numberedReg = RegExp(r'^(\*?\d+[\.\)\-]\*?)\s*(.+)$');
    final bulletReg = RegExp(r'^[\*\-\•]\s*(.+)$');

    for (int i = firstContentLineIdx; i < lines.length; i++) {
      final rawLine = lines[i].trim();
      if (rawLine.isEmpty) continue;

      // Check if numbered: "1. GCS Pump..."
      final numMatch = numberedReg.firstMatch(rawLine);
      if (numMatch != null) {
        final content = numMatch.group(2)!.trim();
        if (content.isNotEmpty) detectedItems.add(content);
        continue;
      }

      // Check if bulleted: "* BF1 & BF2 Sizer..."
      final bulletMatch = bulletReg.firstMatch(rawLine);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)!.trim();
        if (content.isNotEmpty) detectedItems.add(content);
        continue;
      }

      // If line is a title or long paragraph, split into meaningful sentences or lines
      if (rawLine.length > 100) {
        final sentences = rawLine.split(RegExp(r'(?<=\.)\s+'));
        for (final s in sentences) {
          final trimmed = s.trim();
          if (trimmed.length > 5) detectedItems.add(trimmed);
        }
      } else {
        detectedItems.add(rawLine);
      }
    }

    // 5. Detect Area / Equipment keywords
    final allText = text.toUpperCase();
    final knownAreas = [
      'BF1', 'BF2', 'BF-1', 'BF-2', 'MCD', 'GCS', 'CB1', 'CB2', 'CB3', 'CB4', 'CB5', 'CB6', 'CB7',
      'HMC', 'SGC', 'SLAG GRAB CRANE', 'BAGHOUSE CRANE', 'VENTURI', 'MAN COOLER', 'PUMP', 'TRANSFORMER',
      'DG', 'PANEL ROOM', 'ADMIN', 'CANTEEN', 'STORE YARD', 'JETTY', 'THICKENER', 'DUST CATCHER',
      'CAST HOUSE', 'MUDGUN', 'DRILL MC', 'COOLING TOWER', 'WEIGHBRIDGE'
    ];

    for (final area in knownAreas) {
      if (allText.contains(area)) {
        areaSet.add(area.replaceAll('-', ' '));
      }
    }

    // 6. Detect Pending Follow-up items & Status
    final pendingTriggers = [
      'tobe', 'to be', 'tmro', 'tomorrow', 'pending', "couldn't connect",
      'could not connect', 'need to connect', 'next opportunity', 'yet to be',
      'kept under observation', 'observation'
    ];

    for (final item in detectedItems) {
      final lower = item.toLowerCase();
      for (final trigger in pendingTriggers) {
        if (lower.contains(trigger)) {
          pendingNotes.add(item);
          break;
        }
      }
    }

    final isPending = pendingNotes.isNotEmpty;

    // 7. Auto-Categorize based on domain vocabulary
    String category = 'General Maintenance';
    final lowerAll = allText.toLowerCase();

    if (lowerAll.contains('cable') || lowerAll.contains('megger') || lowerAll.contains('cabling') || lowerAll.contains('wire') || lowerAll.contains('core')) {
      category = 'Cabling & Power Distribution';
    } else if (lowerAll.contains('light') || lowerAll.contains('lamp') || lowerAll.contains('tube') || lowerAll.contains('fixture') || lowerAll.contains('40w') || lowerAll.contains('150w')) {
      category = 'Lighting & Illumination';
    } else if (lowerAll.contains('crane') || lowerAll.contains('grab') || lowerAll.contains('hoist') || lowerAll.contains('trolley') || lowerAll.contains('festoon') || lowerAll.contains('sgc')) {
      category = 'Cranes & Material Handling';
    } else if (lowerAll.contains('motor') || lowerAll.contains('pump') || lowerAll.contains('vfd') || lowerAll.contains('drive') || lowerAll.contains('impeller') || lowerAll.contains('decoupled') || lowerAll.contains('man cooler')) {
      category = 'Motors & Drives';
    } else if (lowerAll.contains('pm') || lowerAll.contains('greasing') || lowerAll.contains('dg') || lowerAll.contains('transformer') || lowerAll.contains('shm') || lowerAll.contains('trial') || lowerAll.contains('audit') || lowerAll.contains('buchholz')) {
      category = 'Preventive Maintenance (PM)';
    } else if (lowerAll.contains('actuator') || lowerAll.contains('limit sw') || lowerAll.contains('limit switch') || lowerAll.contains('ls') || lowerAll.contains('switch') || lowerAll.contains('plc') || lowerAll.contains('sensor')) {
      category = 'Instrumentation & Automation';
    } else if (lowerAll.contains('mats') || lowerAll.contains('painting') || lowerAll.contains('canteen') || lowerAll.contains('socket') || lowerAll.contains('renovation') || lowerAll.contains('rubber mat')) {
      category = 'Plant Facilities & Utilities';
    }

    return ParsedWhatsAppLog(
      date: detectedDate ?? DateTime.now(),
      team: detectedTeam,
      items: detectedItems,
      equipmentOrArea: areaSet.take(3).join(', '),
      category: category,
      pendingFollowUp: pendingNotes.isNotEmpty ? pendingNotes.join('\n') : null,
      status: isPending ? 'pending' : 'completed',
      cleanDescription: detectedItems.join('\n'),
    );
  }

  /// Format structured log back to clean WhatsApp format for sharing with team
  static String formatForWhatsApp({
    required DateTime date,
    required String shiftName,
    required List<String> team,
    required List<String> items,
    String? equipmentOrArea,
    String? pendingFollowUp,
    String? status,
  }) {
    final buffer = StringBuffer();
    final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    buffer.writeln('📅 *Date:* $dateStr ($shiftName Shift)');

    if (team.isNotEmpty) {
      buffer.writeln('👥 *Team:* ${team.join(" + ")}');
    }

    if (equipmentOrArea != null && equipmentOrArea.isNotEmpty) {
      buffer.writeln('📍 *Area/Equipment:* $equipmentOrArea');
    }

    buffer.writeln('');
    buffer.writeln('📋 *Jobs Completed:*');
    for (int i = 0; i < items.length; i++) {
      buffer.writeln('${i + 1}. ${items[i]}');
    }

    if (pendingFollowUp != null && pendingFollowUp.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('⚠️ *Pending / Handover to Next Shift:*');
      buffer.writeln(pendingFollowUp.trim());
    }

    buffer.writeln('');
    buffer.writeln('Status: ${status?.toUpperCase() ?? "COMPLETED"}');
    buffer.writeln('Logged via AssetPulse Pro');

    return buffer.toString();
  }
}
