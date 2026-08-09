import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('VEDANTA IRON & STEEL LIMITED',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('PORTABLE TOOLS & EQUIPMENT SAFETY CHECKLIST STANDARDS MANUAL',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                pw.Text('Standard Tag ID Rule: PLANT-UNIT-EQCODE-NO (Firestore Key)',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Divider(color: PdfColors.blue900, thickness: 1.5),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Text('1. Master Equipment Types & Tag ID Code Reference',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 6),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(3.0),
              2: const pw.FlexColumnWidth(1.0),
              3: const pw.FlexColumnWidth(2.0),
              4: const pw.FlexColumnWidth(3.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                children: [
                  _pdfHeaderCell('#'),
                  _pdfHeaderCell('Equipment Type Name'),
                  _pdfHeaderCell('Tag Code'),
                  _pdfHeaderCell('Sample Tag ID'),
                  _pdfHeaderCell('Category'),
                ],
              ),
              _pdfRow('1', 'Welding Machine', 'WM', 'IOG-COD-WM-001', 'Category I: Welding Machine'),
              _pdfRow('2', 'Angle Grinder / Grinder Machine', 'GRN', 'IOG-COD-GRN-001', 'Category II: Grinders & Cutters'),
              _pdfRow('3', 'Cut-Off / Cutting Machine', 'CUT', 'IOG-COD-CUT-001', 'Category II: Grinders & Cutters'),
              _pdfRow('4', 'Drill Machine / SDS Hammer Drill', 'DRL', 'IOG-COD-DRL-001', 'Category III: Power Tools'),
              _pdfRow('5', 'Electrical Breaker / Demolition Hammer', 'BRK', 'IOG-COD-BRK-001', 'Category III: Power Tools'),
              _pdfRow('6', 'Jig Saw / Circular Saw', 'JIG', 'IOG-COD-JIG-001', 'Category III: Power Tools'),
              _pdfRow('7', 'Soldering Iron / Station', 'SLD', 'IOG-COD-SLD-001', 'Category III: Power Tools'),
              _pdfRow('8', 'Air Blower', 'ABL', 'IOG-COD-ABL-001', 'Category IV: Air Blowers & Hot Air'),
              _pdfRow('9', 'Hot Air Gun', 'HAG', 'IOG-COD-HAG-001', 'Category IV: Air Blowers & Hot Air'),
              _pdfRow('10', 'Extension Board / Power PDU', 'EXT', 'IOG-COD-EXT-001', 'Category V: Extension & Cable Drums'),
              _pdfRow('11', 'Welding Cable Assembly / Earthing Cable', 'WMC', 'IOG-COD-WMC-001', 'Category V: Extension & Cable Drums'),
              _pdfRow('12', 'Submersible Pump', 'SUB', 'IOG-COD-SUB-001', 'Category VI: Submersible & Pumps'),
              _pdfRow('13', 'Jet Pump / High Pressure Washer', 'JTP', 'IOG-COD-JTP-001', 'Category VI: Submersible & Pumps'),
              _pdfRow('14', 'Vacuum Pump / Vacuum Cleaner', 'VCP', 'IOG-COD-VCP-001', 'Category VI: Submersible & Pumps'),
              _pdfRow('15', 'Sterilizer / Autoclave Unit', 'STR', 'IOG-COD-STR-001', 'Category VII: General Equipment'),
              _pdfRow('16', 'Industrial Mixer Machine', 'MIX', 'IOG-COD-MIX-001', 'Category VII: General Equipment'),
              _pdfRow('17', 'Fogging Gun / Disinfection Unit', 'FOG', 'IOG-COD-FOG-001', 'Category VII: General Equipment'),
              _pdfRow('18', 'Other Portable Equipment', 'OTH', 'IOG-COD-OTH-001', 'Category VII: General Equipment'),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('2. Standard Safety Checkpoints Manual by Category',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 8),

          _buildCategoryBlock('Category I: Welding Machines (WM)', [
            '1. Primary Supply & Plug: Industrial IEC 60309 splashproof plug, cable glanding & no joints',
            '2. VRD (Voltage Reduction Device): Fitted & reduces idle Open Circuit Voltage (OCV) <= 30V',
            '3. Body Leakage Voltage: Casing to neutral/earth leakage voltage <= 50V AC RMS',
            '4. Insulation Resistance (IR): Megger test >= 2.0 Megohms between live parts and chassis',
            '5. Output Connectors & Cable: Fully insulated DINSE connectors & heavy-duty flexible cable',
            '6. Electrode Holder & Earth Clamp: Fully insulated holder & heavy-duty earth clamp with braid',
            '7. RCCB / ELCB Protection: Built-in 30mA RCCB test button operation & ON lamp indicator',
            '8. Thermal Cut-Off & Cooling Fan: Internal cooling fan operational & thermal trip cut-off intact',
            '9. Chassis & Earthing Integrity: Dedicated earthing boss terminal with serrated washer & locked Tag ID',
            '10. Unsafe Lock-Out Protocol: If leakage >50V or IR <2M-ohm or VRD fails, disconnect & lock in electrical custody',
          ]),

          _buildCategoryBlock('Category II: Grinders & Cutting Tools (GRN, CUT)', [
            '1. Safety Wheel Guard: Physical presence & 180-degree adjustment lock intact (never removed/modified)',
            '2. Design Speed Matching: Wheel/blade rated design speed >= machine rated RPM',
            '3. Deadman / Non-Locking Switch: Spring-loaded paddle/deadman switch stops tool when released',
            '4. Class II Double Insulation: Square-in-square symbol present, casing free of cracks/oil ingress',
            '5. Auxiliary Side Handle: Secondary side handle firmly attached for two-handed control',
            '6. Power Cable & Plug: HO7RN-F heavy-duty rubber cable without joints, 3-pin industrial plug',
            '7. Spindle & Arbor Condition: Spindle free of excessive play, wobble, or abnormal vibration',
            '8. Tag ID & Relief Sleeve: Machine Tag ID affixed, cable strain relief sleeve intact',
          ]),

          _buildCategoryBlock('Category III: Drills, Breakers, Saws & Soldering Irons (DRL, BRK, JIG, SLD)', [
            '1. Power Cable & Plug: HO7RN-F rubber cable without joints/cuts, 3-pin industrial plug',
            '2. Trigger Switch & Lock-Off Safety: Switch operating smoothly with deadman cut-off safety',
            '3. Tool Holder / Chuck Retainer: Drill chuck / SDS retainer / blade clamp in sound condition',
            '4. Double Insulation / Earthing: Class II double insulation casing intact (or earthing verified <= 1-ohm)',
            '5. Handle Insulation & Grip: Primary operating handle insulation clean, dry & undamaged',
            '6. Tag ID & Visual Integrity: Machine Tag ID affixed, no loose or missing assembly screws',
          ]),

          _buildCategoryBlock('Category IV: Air Blowers & Hot Air Guns (ABL, HAG)', [
            '1. Power Cable & Plug: Heavy-duty rubber cable without burns/cuts, industrial molded plug',
            '2. Air Intake Guard / Screen: Intake mesh clean & firmly secured (prevents debris suction)',
            '3. Nozzle & Heat Shield: Heat barrier guard intact; thermal cut-off operating',
            '4. Enclosure Integrity & Earthing: High-impact heat-resistant casing free of cracks & earthed',
            '5. Tag ID Affixed: Machine Tag ID affixed & readable',
          ]),

          _buildCategoryBlock('Category V: Extension Boards & Cable Drums (EXT, WMC)', [
            '1. RCCB / ELCB 30mA Protection: Built-in 30mA / 30ms sensitivity RCCB with functional test button',
            '2. IP44 / IP54 Weatherproof Sockets: Weatherproof enclosure with spring-loaded self-closing flap covers',
            '3. Individual Socket MCBs: Overcurrent MCB protection for each socket outlet (16A / 32A)',
            '4. Industrial Rubber Cable: HO7RN-F flexible rubber cable without joints or outer sheath cuts',
            '5. Earthing Continuity: Continuous earthing path from main inlet plug to all output sockets (<= 1-ohm)',
            '6. Tag ID & Reel Thermal Cut-Out: Identification Tag ID affixed & cable reel thermal trip intact',
          ]),

          _buildCategoryBlock('Category VI: Submersible & Industrial Pumps (SUB, JTP, VCP)', [
            '1. Mechanical Seal Oil Chamber: Mechanical oil seal free of water contamination or leakage',
            '2. Suspension Wire Rope: Pump suspended by stainless steel rope (NEVER by power cable)',
            '3. Float Switch & Auto Control: Waterproof float switch cabling & auto-on/off operation',
            '4. Cable Entry Gland & Relief: Cable entry gland sealed & strain relief clamp secured',
            '5. Earthing & 30mA RCCB: 30mA RCCB protection & continuous ground connection to pump casing',
            '6. Tag ID & Casing Condition: Equipment Tag ID affixed & impeller guard free of debris',
          ]),

          _buildCategoryBlock('Category VII: Other General Equipment (STR, MIX, FOG, OTH)', [
            '1. Power Cable & Industrial Plug: HO7RN-F rubber cable without joints, 3-pin industrial plug',
            '2. Power Switch & Emergency Stop: Functional power switch & emergency stop button',
            '3. Body Earthing & Insulation: Grounding continuity verified or Class II double-insulation intact',
            '4. Protective Covers & Guards: Protective covers/guards intact, casing free of cracks',
            '5. Tag ID Affixed: Equipment Tag ID affixed & readable',
          ]),
        ];
      },
    ),
  );

  final bytes = await pdf.save();

  final artifactDir = Directory(r'C:\Users\aswat\.gemini\antigravity-ide\brain\778c8f01-9c76-4971-baf9-e93d104af956');
  final artifactFile = File('${artifactDir.path}\\Portable_Tools_Equipment_Checklist_Standards.pdf');
  await artifactFile.writeAsBytes(bytes);
  print('PDF successfully saved to Artifact path: ${artifactFile.path}');

  final userDownloads = Directory('${Platform.environment['USERPROFILE']}\\Downloads');
  if (userDownloads.existsSync()) {
    final downloadFile = File('${userDownloads.path}\\Portable_Tools_Equipment_Checklist_Standards.pdf');
    await downloadFile.writeAsBytes(bytes);
    print('PDF successfully saved to User Downloads: ${downloadFile.path}');
  }
}

pw.Widget _pdfHeaderCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
  );
}

pw.TableRow _pdfRow(String seq, String name, String code, String sampleId, String category) {
  return pw.TableRow(
    children: [
      _cell(seq),
      _cell(name),
      _cell(code, isBold: true),
      _cell(sampleId, isBold: true),
      _cell(category),
    ],
  );
}

pw.Widget _cell(String text, {bool isBold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );
}

pw.Widget _buildCategoryBlock(String title, List<String> points) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 4),
        ...points.map((pt) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text('• $pt', style: const pw.TextStyle(fontSize: 8)),
            )),
      ],
    ),
  );
}
