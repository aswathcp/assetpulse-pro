import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RccbCertificationTagPdfHelper {
  /// Generates an A4 PDF containing an optimized 2 columns x 4 rows (8 tags per page) grid.
  /// Supports two distinct tag modes:
  /// 1. [isPermanent = false]: Periodic Audit Certification Tag (with breaker tripping readings, 3-month next due date, test results, and inspector name).
  /// 2. [isPermanent = true]: Permanent Equipment ID Tag (permanent panel plate with extra-large scannable QR, equipment name, incoming feeder, RCCB capacity & rating, without test readings).
  static Future<pw.Document> generateCertificationTagsPdf({
    required List<Map<String, dynamic>> equipments,
    String? plantName,
    String? unitName,
    bool isPermanent = false,
  }) async {
    final pdf = pw.Document();

    const int tagsPerPage = 8; // Optimized 2x4 grid to maximize page efficiency and eliminate excess space
    for (int i = 0; i < equipments.length; i += tagsPerPage) {
      final end = (i + tagsPerPage < equipments.length) ? i + tagsPerPage : equipments.length;
      final pageEquipments = equipments.sublist(i, end);
      final int totalRows = ((pageEquipments.length - 1) ~/ 2) + 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Top Page Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isPermanent
                          ? 'VEDANTA IRON & STEEL LIMITED - PERMANENT ELECTRICAL EQUIPMENT ID TAGS'
                          : 'VEDANTA IRON & STEEL LIMITED - RCCB ELECTRICAL SAFETY CERTIFICATION TAGS',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.Text(
                      'Plant: ${plantName ?? "All Plants"} | Unit: ${unitName ?? "All Units"} | Sheet ${(i ~/ tagsPerPage) + 1} of ${((equipments.length - 1) ~/ tagsPerPage) + 1}',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Optimized 2-Column Grid (Only renders required rows; spacer at bottom prevents artificial stretching)
                for (int rowIndex = 0; rowIndex < totalRows; rowIndex++) ...[
                  if (rowIndex > 0) pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      for (int colIndex = 0; colIndex < 2; colIndex++) ...[
                        if (colIndex > 0) pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: (rowIndex * 2 + colIndex < pageEquipments.length)
                              ? (isPermanent
                                  ? _buildPermanentTag(pageEquipments[rowIndex * 2 + colIndex], plantName: plantName, unitName: unitName)
                                  : _buildAuditTag(pageEquipments[rowIndex * 2 + colIndex]))
                              : pw.Container(),
                        ),
                      ],
                    ],
                  ),
                ],

                // Pusher spacer: If only 1 or 2 tags are on the page, they remain at the top neatly sized
                pw.Spacer(),

                pw.SizedBox(height: 4),
                // Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isPermanent
                          ? 'Equipment Identity Plate | Standards: IEC 61008-1 / IS 12640 / BS 7671 | Permanent Labeling'
                          : 'Audit Cycle: 3 Months (90 Days) | Standards: IEC 61008-1 / IS 12640 / BS 7671 (1x <= 300ms, 5x <= 40ms)',
                      style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Generated: ${DateTime.now().toString().split(".")[0]}',
                      style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }

  // ==========================================
  // 1. AUDIT CERTIFICATION TAG (Dynamic Readings)
  // ==========================================
  static pw.Widget _buildAuditTag(Map<String, dynamic> equipment) {
    final rawId = equipment['displayId'] ?? equipment['id']?.toString() ?? 'RCCB-POINT';
    final category = equipment['category']?.toString() ?? 'LDB';
    final location = equipment['location']?.toString() ?? 'No Location';
    final incomingSource = equipment['incomingSource']?.toString() ?? 'Panel Feed';
    final rccbCount = equipment['rccbCount'] as int? ?? 1;
    final defaultRating = equipment['defaultRating']?.toString() ?? '30mA';

    final latestReport = equipment['latestReport'] as Map<String, dynamic>?;
    final status = equipment['status']?.toString() ?? 'Never Tested';

    DateTime? lastTested;
    DateTime? nextDue;
    if (latestReport != null && latestReport['testingDate'] != null) {
      try {
        lastTested = DateTime.parse(latestReport['testingDate']);
        // 3-month (90 days) audit validity
        nextDue = lastTested.add(const Duration(days: 90));
      } catch (_) {}
    }

    final isCompliant = status == 'Compliant';
    final isFailed = status == 'Failed';

    final PdfColor statusBg = isCompliant
        ? PdfColors.green700
        : isFailed
            ? PdfColors.red700
            : (status == 'Never Tested' ? PdfColors.grey700 : PdfColors.orange700);

    final String statusText = isCompliant
        ? 'COMPLIANT (VALID - 3 MONTHS)'
        : isFailed
            ? 'FAILED (ACTION REQUIRED)'
            : (status == 'Never Tested' ? 'NEVER TESTED (PENDING AUDIT)' : 'OVERDUE FOR AUDIT');

    // Equipment Category Banner Color
    PdfColor categoryColor = PdfColors.orange800;
    if (category == 'Welding Outlet') {
      categoryColor = PdfColors.purple800;
    } else if (category == 'Power Socket') {
      categoryColor = PdfColors.teal800;
    }

    final testedBy = latestReport?['testedBy']?.toString() ?? 'Pending Tech';
    final qrData = 'RCCB:${equipment['id']}';

    // Map breaker logs
    final rccbLogs = latestReport != null ? (latestReport['rccbLogs'] as List<dynamic>? ?? []) : [];
    final Map<int, Map<String, dynamic>> loggedBreakers = {};
    for (var log in rccbLogs) {
      final no = log['rccbNo'] as int?;
      if (no != null) {
        loggedBreakers[no] = Map<String, dynamic>.from(log);
      }
    }

    return pw.Container(
      height: 185,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.blueGrey900, width: 1.2),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. Tag Top Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: pw.BoxDecoration(
              color: categoryColor,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'VEDANTA QA • RCCB SAFETY CERTIFICATION',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    category.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Content
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(5, 4, 5, 3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Top Row: QR Code + Key Specifications
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Scannable High-Contrast QR Code
                      pw.Container(
                        width: 62,
                        height: 62,
                        padding: const pw.EdgeInsets.all(2.5),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColors.blueGrey800, width: 0.9),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                          color: PdfColors.black,
                          backgroundColor: PdfColors.white,
                          drawText: false,
                        ),
                      ),
                      pw.SizedBox(width: 6),

                      // Equipment Identification & Meta
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  rawId,
                                  style: pw.TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.blueGrey900,
                                  ),
                                ),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.grey200,
                                    borderRadius: pw.BorderRadius.circular(2),
                                  ),
                                  child: pw.Text(
                                    '$rccbCount Unit(s) • $defaultRating',
                                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Loc: $location',
                              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                              maxLines: 1,
                            ),
                            pw.Text(
                              'Feed: $incomingSource',
                              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                              maxLines: 1,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Last Test:', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey600)),
                                    pw.Text(
                                      lastTested != null ? '${lastTested.day.toString().padLeft(2, '0')}/${lastTested.month.toString().padLeft(2, '0')}/${lastTested.year}' : 'Never',
                                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                                    ),
                                  ],
                                ),
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Next Due:', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey600)),
                                    pw.Text(
                                      nextDue != null ? '${nextDue.day.toString().padLeft(2, '0')}/${nextDue.month.toString().padLeft(2, '0')}/${nextDue.year}' : 'Immediate',
                                      style: pw.TextStyle(
                                        fontSize: 6.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: nextDue == null || nextDue.isBefore(DateTime.now())
                                            ? PdfColors.red800
                                            : (nextDue.difference(DateTime.now()).inDays <= 15 ? PdfColors.orange800 : PdfColors.black),
                                      ),
                                    ),
                                    if (nextDue != null)
                                      pw.Text(
                                        nextDue.isBefore(DateTime.now())
                                            ? '(Overdue)'
                                            : (nextDue.difference(DateTime.now()).inDays <= 15
                                                ? '(${nextDue.difference(DateTime.now()).inDays}d left)'
                                                : '(Valid)'),
                                        style: pw.TextStyle(
                                          fontSize: 5,
                                          fontWeight: pw.FontWeight.bold,
                                          color: nextDue.isBefore(DateTime.now())
                                              ? PdfColors.red800
                                              : (nextDue.difference(DateTime.now()).inDays <= 15 ? PdfColors.orange800 : PdfColors.green800),
                                        ),
                                      ),
                                  ],
                                ),
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text('Tested By:', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey600)),
                                    pw.Text(
                                      testedBy,
                                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),

                  // 3. Breaker Test Results Table (Shows individual breaker trip readings)
                  pw.Text(
                    'RECORDED BREAKER TEST RESULTS (IEC 61008-1)',
                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                  ),
                  pw.SizedBox(height: 1.5),

                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildTableTh('Breaker'),
                          _buildTableTh('Rating'),
                          _buildTableTh('1x (<=300ms)'),
                          _buildTableTh('5x (<=40ms)'),
                          _buildTableTh('Result'),
                        ],
                      ),
                      // Display breaker rows (cap at 3 to fit neat height if large count)
                      for (int b = 1; b <= (rccbCount > 3 ? 3 : rccbCount); b++) ...[
                        _buildBreakerRow(b, loggedBreakers[b], defaultRating, status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Status Bar Bottom
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
            decoration: pw.BoxDecoration(
              color: statusBg,
              borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(3)),
            ),
            child: pw.Center(
              child: pw.Text(
                statusText,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. PERMANENT EQUIPMENT ID TAG (Static Panel Tag)
  // ==========================================
  static pw.Widget _buildPermanentTag(
    Map<String, dynamic> equipment, {
    String? plantName,
    String? unitName,
  }) {
    final rawId = equipment['displayId'] ?? equipment['id']?.toString() ?? 'RCCB-POINT';
    final category = equipment['category']?.toString() ?? 'LDB';
    final location = equipment['location']?.toString() ?? 'Plant Location';
    final incomingSource = equipment['incomingSource']?.toString() ?? 'Main Feeder Panel';
    final rccbCount = equipment['rccbCount'] as int? ?? 1;
    final defaultRating = equipment['defaultRating']?.toString() ?? '30mA';

    // Equipment Category Banner Color
    PdfColor categoryColor = PdfColors.orange800;
    if (category == 'Welding Outlet') {
      categoryColor = PdfColors.purple800;
    } else if (category == 'Power Socket') {
      categoryColor = PdfColors.teal800;
    }

    final qrData = 'RCCB:${equipment['id']}';

    return pw.Container(
      height: 185,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.blueGrey900, width: 1.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. Tag Top Header Banner (Industrial Identity Plate)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(
              color: categoryColor,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'VEDANTA QA • ELECTRICAL ASSET IDENTITY',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    category.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Content
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Upper Row: Extra Large QR Code (76x76) + Permanent Specifications
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Large Scannable QR Code with scan instruction label
                      pw.Column(
                        children: [
                          pw.Container(
                            width: 76,
                            height: 76,
                            padding: const pw.EdgeInsets.all(3),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              border: pw.Border.all(color: PdfColors.blueGrey900, width: 1.2),
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrData,
                              color: PdfColors.black,
                              backgroundColor: PdfColors.white,
                              drawText: false,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'SCAN TO INSPECT',
                            style: pw.TextStyle(
                              fontSize: 5.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey800,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(width: 8),

                      // Permanent Equipment Identification & Specifications
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              rawId,
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blueGrey900,
                              ),
                            ),
                            pw.Text(
                              category == 'LDB'
                                  ? 'Lighting Distribution Board'
                                  : (category == 'Welding Outlet' ? 'Welding Receptacle Outlet' : 'Industrial Power Socket'),
                              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                            ),
                            pw.SizedBox(height: 3),

                            // Specifications Box
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  _buildSpecRow('Location:', location, isBold: true),
                                  pw.SizedBox(height: 1.5),
                                  _buildSpecRow('Incomer / Feed:', incomingSource),
                                  pw.SizedBox(height: 1.5),
                                  _buildSpecRow('RCCB Capacity:', '$rccbCount Breaker Unit(s)', highlight: true),
                                  pw.SizedBox(height: 1.5),
                                  _buildSpecRow('Trip Sensitivity:', defaultRating, highlight: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Lower Notice Box: Permanent Maintenance & Safety Standards
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor(0.95, 0.96, 0.98),
                      border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '• Permanent panel identification tag. Do not remove, repaint, or deface.',
                          style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          '• Safety Standard: IEC 61008-1 / IS 12640 / BS 7671 | Mandatory 3-Month Audit Cycle.',
                          style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey800),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          '• Plant: ${plantName ?? "Main Plant"} | Unit: ${unitName ?? "Operations"}',
                          style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Permanent Plate Bottom Banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(2.5)),
            ),
            child: pw.Center(
              child: pw.Text(
                'PERMANENT EQUIPMENT IDENTITY PLATE • DO NOT REMOVE',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSpecRow(String label, String value, {bool isBold = false, bool highlight = false}) {
    return pw.Row(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
        pw.SizedBox(width: 3),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 6,
              fontWeight: isBold || highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: highlight ? PdfColors.blueGrey900 : PdfColors.black,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableTh(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.TableRow _buildBreakerRow(int breakerNo, Map<String, dynamic>? log, String defaultRating, String boardStatus) {
    final rating = log?['rating'] ?? defaultRating;
    final t1x = log?['trippingTime1x'] != null ? '${log!['trippingTime1x']} ms' : '-';
    final t5x = log?['trippingTime5x'] != null ? '${log!['trippingTime5x']} ms' : '-';

    String resultText;
    PdfColor resultColor;

    if (log != null && log['result'] != null) {
      final isPass = log['result'] == 'Pass';
      resultText = isPass ? 'PASS' : 'FAIL';
      resultColor = isPass ? PdfColors.green800 : PdfColors.red800;
    } else {
      if (boardStatus == 'Overdue') {
        resultText = 'OVERDUE';
        resultColor = PdfColors.orange800;
      } else {
        resultText = 'NOT TESTED';
        resultColor = PdfColors.grey700;
      }
    }

    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          child: pw.Text('RCCB-$breakerNo', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          child: pw.Text(rating, style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          child: pw.Text(t1x, style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          child: pw.Text(t5x, style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          child: pw.Text(
            resultText,
            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: resultColor),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }
}
