import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:asset_pulse_pro/features/assets/data/models/asset_model.dart';

class AssetCertificationTagPdfHelper {
  /// Generates an A4 PDF containing 2 columns x 3 rows (6 tags per page) of certification tags.
  /// Formatted with wide gutters, type-specific diagnostic test data only, and accurate certification status.
  static Future<pw.Document> generateCertificationTagsPdf({
    required List<AssetModel> assets,
    String? plantName,
    String? unitName,
  }) async {
    final pdf = pw.Document();

    const int tagsPerPage = 6;
    for (int i = 0; i < assets.length; i += tagsPerPage) {
      final end = (i + tagsPerPage < assets.length) ? i + tagsPerPage : assets.length;
      final pageAssets = assets.sublist(i, end);

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
                      'VEDANTA IRON & STEEL LIMITED - PERIODIC ASSET HEALTH & QA CERTIFICATION TAGS',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.Text(
                      'Plant: ${plantName ?? "All Plants"} | Unit: ${unitName ?? "All Units"} | Sheet ${(i ~/ tagsPerPage) + 1} of ${((assets.length - 1) ~/ tagsPerPage) + 1}',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),

                // 2 columns x 3 rows Grid with generous cutting gaps
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      for (int rowIndex = 0; rowIndex < 3; rowIndex++) ...[
                        if (rowIndex > 0) pw.SizedBox(height: 20), // Wide vertical cutting clearance
                        pw.Expanded(
                          child: pw.Row(
                            children: [
                              for (int colIndex = 0; colIndex < 2; colIndex++) ...[
                                if (colIndex > 0) pw.SizedBox(width: 18), // Wide horizontal cutting clearance
                                pw.Expanded(
                                  child: (rowIndex * 2 + colIndex < pageAssets.length)
                                      ? _buildSingleCertificationTag(pageAssets[rowIndex * 2 + colIndex])
                                      : pw.Container(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }

  static pw.Widget _buildSingleCertificationTag(AssetModel asset) {
    // Check if asset has actually been tested before
    final bool wasTestedBefore = asset.lastServiceDate != null ||
        asset.insulationResistance != null ||
        asset.windingResistance != null ||
        asset.vibration != null ||
        (asset.specs != null &&
            (asset.specs!['fanCondition'] != null ||
                asset.specs!['backlash'] != null ||
                asset.specs!['head'] != null ||
                asset.specs!['stroke'] != null ||
                asset.specs!['feedbackSignal'] != null));

    final bool isHealthy = asset.healthStatus == AssetHealthStatus.healthy;
    final bool isWarning = asset.healthStatus == AssetHealthStatus.warning;

    final DateTime? lastTested = asset.lastServiceDate;
    final DateTime? nextDue = asset.nextServiceDue ?? lastTested?.add(const Duration(days: 180));
    final bool isExpired = lastTested != null && DateTime.now().isAfter(lastTested.add(const Duration(days: 180)));

    final String statusTitle;
    final PdfColor statusColor;
    final PdfColor statusBg;
    final String lastTestedStr;
    final String validityCycleStr;
    final String nextDueStr;
    final String digitalSealStr;
    final PdfColor digitalSealColor;
    final String inspectorName;
    final String footerSubtitle;
    final PdfColor footerDotColor;

    if (!wasTestedBefore) {
      // 1. NEVER TESTED (Pending initial 6-month checkup)
      statusTitle = 'PENDING INITIAL CERTIFICATION';
      statusColor = PdfColors.blueGrey800;
      statusBg = PdfColors.grey100;
      lastTestedStr = 'Not Tested Yet';
      validityCycleStr = 'Pending (6-Mo Cycle)';
      nextDueStr = 'Check Required';
      digitalSealStr = 'Pending QA Sign-Off';
      digitalSealColor = PdfColors.grey700;
      inspectorName = 'Unassigned / Awaiting Test';
      footerSubtitle = 'Inspection Pending - Complete 6-Month Health Check to Certify';
      footerDotColor = PdfColors.grey500;
    } else if (isExpired && isHealthy) {
      // 2. TESTED EARLIER, BUT EXPIRED (> 6 Months / 180 Days)
      statusTitle = 'CERTIFICATION EXPIRED (RECERTIFY)';
      statusColor = PdfColors.orange900;
      statusBg = PdfColors.orange50;
      lastTestedStr = "${lastTested.year}-${_twoDigits(lastTested.month)}-${_twoDigits(lastTested.day)}";
      validityCycleStr = 'Expired (> 180 Days)';
      nextDueStr = nextDue != null ? "${nextDue.year}-${_twoDigits(nextDue.month)}-${_twoDigits(nextDue.day)} (OVERDUE)" : "Overdue";
      digitalSealStr = 'Expired - Recertify';
      digitalSealColor = PdfColors.orange900;
      inspectorName = (asset.modifiedBy != null && asset.modifiedBy!.isNotEmpty)
          ? asset.modifiedBy!.split('@').first
          : 'Prior QC Tech';
      footerSubtitle = 'Prior 6-Month Period Elapsed - Recertification Required';
      footerDotColor = PdfColors.orange700;
    } else if (isHealthy) {
      // 3. HEALTHY & VALID (Within 6 Months)
      statusTitle = 'CERTIFIED HEALTHY (PASS)';
      statusColor = PdfColors.green800;
      statusBg = PdfColors.green50;
      lastTestedStr = "${lastTested!.year}-${_twoDigits(lastTested.month)}-${_twoDigits(lastTested.day)}";
      validityCycleStr = '6 Months (180 Days Valid)';
      nextDueStr = nextDue != null ? "${nextDue.year}-${_twoDigits(nextDue.month)}-${_twoDigits(nextDue.day)}" : "-";
      digitalSealStr = 'Biometric Verified';
      digitalSealColor = PdfColors.green800;
      inspectorName = (asset.modifiedBy != null && asset.modifiedBy!.isNotEmpty)
          ? asset.modifiedBy!.split('@').first
          : 'QC Tech';
      footerSubtitle = 'Hardware Biometric QA Verification';
      footerDotColor = PdfColors.green700;
    } else if (isWarning) {
      // 4. ATTENTION / RE-CHECK
      statusTitle = 'ATTENTION / RE-CHECK';
      statusColor = PdfColors.orange800;
      statusBg = PdfColors.orange50;
      lastTestedStr = lastTested != null ? "${lastTested.year}-${_twoDigits(lastTested.month)}-${_twoDigits(lastTested.day)}" : "Tested";
      validityCycleStr = 'Attention Required';
      nextDueStr = 'Immediate Maintenance';
      digitalSealStr = 'Flagged / Attention';
      digitalSealColor = PdfColors.orange800;
      inspectorName = (asset.modifiedBy != null && asset.modifiedBy!.isNotEmpty)
          ? asset.modifiedBy!.split('@').first
          : 'QC Tech';
      footerSubtitle = 'Diagnostic Fault Flagged - Maintenance Required';
      footerDotColor = PdfColors.orange700;
    } else {
      // 5. CRITICAL DEFECT / LOCKOUT
      statusTitle = 'CRITICAL DEFECT / LOCKOUT';
      statusColor = PdfColors.red800;
      statusBg = PdfColors.red50;
      lastTestedStr = lastTested != null ? "${lastTested.year}-${_twoDigits(lastTested.month)}-${_twoDigits(lastTested.day)}" : "Tested";
      validityCycleStr = 'Lockout / Non-Compliant';
      nextDueStr = 'Immediate Overhaul';
      digitalSealStr = 'Defect / Lockout';
      digitalSealColor = PdfColors.red800;
      inspectorName = (asset.modifiedBy != null && asset.modifiedBy!.isNotEmpty)
          ? asset.modifiedBy!.split('@').first
          : 'QC Tech';
      footerSubtitle = 'Lockout Active - Severe Diagnostic Defect Logged';
      footerDotColor = PdfColors.red700;
    }

    // Parent & Spares Info
    final String parentEq = asset.masterEquipmentId.isNotEmpty ? asset.masterEquipmentId : 'Standalone / Fleet Spare';
    final String applicableSpares = (asset.applicableParentEquipmentIds != null && asset.applicableParentEquipmentIds!.isNotEmpty)
        ? asset.applicableParentEquipmentIds!.join(', ')
        : 'Universal Fleet Interchangeable';
    final String storageLocation = (asset.spareLocation != null && asset.spareLocation!.isNotEmpty)
        ? asset.spareLocation!
        : (asset.status == AssetStatus.spare ? 'Central Warehouse' : 'Installed at $parentEq');

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blueGrey700, width: 1.1),
      ),
      child: pw.Stack(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(7, 4, 7, 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // 1. Tag Header Banner
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VEDANTA IRON & STEEL LIMITED',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.Text(
                          'PERIODIC ASSET HEALTH & QA CERTIFICATION TAG',
                          style: pw.TextStyle(fontSize: 5.2, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.2),
                      decoration: pw.BoxDecoration(
                        color: statusBg,
                        borderRadius: pw.BorderRadius.circular(3),
                        border: pw.Border.all(color: statusColor, width: 0.8),
                      ),
                      child: pw.Text(
                        statusTitle,
                        style: pw.TextStyle(color: statusColor, fontWeight: pw.FontWeight.bold, fontSize: 5.2),
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.5, color: PdfColors.grey400, height: 3),

                // 2. Identity & QR Code Row
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // High-Contrast Scannable QR Code with Quiet Zone
                    pw.Container(
                      width: 52,
                      height: 52,
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: PdfColors.blueGrey800, width: 0.8),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: asset.tagNo.trim(),
                        color: PdfColors.black,
                        backgroundColor: PdfColors.white,
                        drawText: false,
                      ),
                    ),
                    pw.SizedBox(width: 6),

                    // Asset Info & Operational Context
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                asset.tagNo,
                                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                              ),
                              pw.SizedBox(width: 4),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: pw.BoxDecoration(
                                  color: asset.status == AssetStatus.spare ? PdfColors.cyan50 : PdfColors.orange50,
                                  borderRadius: pw.BorderRadius.circular(2),
                                  border: pw.Border.all(color: asset.status == AssetStatus.spare ? PdfColors.cyan800 : PdfColors.orange800, width: 0.5),
                                ),
                                child: pw.Text(
                                  asset.status.name.toUpperCase(),
                                  style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold, color: asset.status == AssetStatus.spare ? PdfColors.cyan900 : PdfColors.orange900),
                                ),
                              ),
                              if (asset.isCritical) ...[
                                pw.SizedBox(width: 3),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.amber50,
                                    borderRadius: pw.BorderRadius.circular(2),
                                    border: pw.Border.all(color: PdfColors.amber800, width: 0.5),
                                  ),
                                  child: pw.Text(
                                    'CRITICAL SPARE',
                                    style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          pw.Text(
                            asset.name.isNotEmpty ? asset.name : '${asset.type.name.toUpperCase()} ASSET',
                            maxLines: 1,
                            style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                          ),
                          pw.Text(
                            'Parent Eq: $parentEq  |  Bay/Loc: $storageLocation',
                            maxLines: 1,
                            style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.blueGrey800),
                          ),
                          pw.Text(
                            'Compatible Spares: $applicableSpares',
                            maxLines: 1,
                            style: pw.TextStyle(fontSize: 5, color: PdfColors.indigo900, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Make: ${asset.make.isNotEmpty ? asset.make : "-"} | Model: ${asset.model.isNotEmpty ? asset.model : "-"} | S/N: ${asset.serialNo.isNotEmpty ? asset.serialNo : "-"} | PO: ${asset.poNo ?? "-"}',
                            maxLines: 1,
                            style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 3. Technical Rating Specs Box
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: _buildTypeSpecificSpecsWidget(asset),
                ),

                // 4. Detailed Diagnostic Measurements Table (Applicable parameters ONLY)
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: _buildDiagnosticHeaders(asset),
                    ),
                    pw.TableRow(
                      children: _buildDiagnosticValues(asset, isHealthy, wasTestedBefore),
                    ),
                  ],
                ),

                // 5. 6-Month Period & Recertification Grid
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        _pdfCell('Tested Date', isHeader: true),
                        _pdfCell('Validity Cycle', isHeader: true),
                        _pdfCell('Next Recertification Due', isHeader: true),
                        _pdfCell('Digital Seal Sign-Off', isHeader: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfCell(lastTestedStr, isBold: true),
                        _pdfCell(validityCycleStr, isBold: true, color: PdfColors.blue900),
                        _pdfCell(nextDueStr, isBold: true, color: statusColor),
                        _pdfCell(digitalSealStr, isBold: true, color: digitalSealColor),
                      ],
                    ),
                  ],
                ),

                // 6. Signature & Digital Seal Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Certified Inspector: $inspectorName', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
                        pw.Row(
                          children: [
                            pw.Container(
                              width: 3.5,
                              height: 3.5,
                              decoration: pw.BoxDecoration(color: footerDotColor, shape: pw.BoxShape.circle),
                            ),
                            pw.SizedBox(width: 2),
                            pw.Text(footerSubtitle, style: pw.TextStyle(fontSize: 4.8, color: footerDotColor)),
                          ],
                        ),
                      ],
                    ),
                    pw.Text(
                      'Attach securely to motor frame / terminal box via hole using cable tie',
                      style: pw.TextStyle(fontSize: 4.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Punch Hole Guide Marker at top center
          pw.Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: pw.Center(
              child: pw.Container(
                width: 5.5,
                height: 5.5,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTypeSpecificSpecsWidget(AssetModel asset) {
    if (asset.type == AssetType.motor) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Power: ${asset.powerKw != null ? "${asset.powerKw} kW" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Volt: ${asset.voltage != null ? "${asset.voltage} V" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('FLC: ${asset.fullLoadCurrent != null ? "${asset.fullLoadCurrent} A" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('RPM: ${asset.speedRpm != null ? "${asset.speedRpm}" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Frame: ${asset.frameSize ?? "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Ins: ${asset.insulationClass ?? "Class F"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Mount: ${asset.mountingType ?? "Foot B3"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
        ],
      );
    } else if (asset.type == AssetType.gearbox) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Ratio: ${asset.gearRatio ?? "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('In/Out RPM: ${asset.inputSpeedRpm ?? "-"}/${asset.outputSpeedRpm ?? "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Oil: ${asset.oilType ?? "-"} (${asset.oilCapacity ?? "-"} L)', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Lube: ${asset.lubricationMethod ?? "Splash / Forced"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
        ],
      );
    } else if (asset.type == AssetType.pump) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Flow: ${asset.flowRate != null ? "${asset.flowRate} m3/h" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Head: ${asset.head != null ? "${asset.head} m" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Power: ${asset.pumpPower != null ? "${asset.pumpPower} kW" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Impeller: ${asset.impellerSize ?? "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Seal: ${asset.sealType ?? "Mech Seal"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
        ],
      );
    } else if (asset.type == AssetType.brake) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Brake: ${asset.brakeType ?? "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Thruster: ${asset.thrusterCapacityKg != null ? "${asset.thrusterCapacityKg} kg" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Drum Dia: ${asset.drumDiaMm != null ? "${asset.drumDiaMm} mm" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Torque: ${asset.brakingTorqueNm != null ? "${asset.brakingTorqueNm} Nm" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
        ],
      );
    } else {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Actuator: ${asset.actuatorType ?? "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Torque/Thrust: ${asset.torqueOrThrust != null ? "${asset.torqueOrThrust} Nm/kN" : "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Control: ${asset.controlSignal ?? "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
          pw.Text('Valve: ${asset.valveSize ?? "-"}', style: const pw.TextStyle(fontSize: 5.2, color: PdfColors.black)),
        ],
      );
    }
  }

  static List<pw.Widget> _buildDiagnosticHeaders(AssetModel asset) {
    if (asset.type == AssetType.motor) {
      return [
        _pdfCell('Lowest IR (Phase-Earth)', isHeader: true),
        _pdfCell('Winding Bal (% Dev)', isHeader: true),
        _pdfCell('Vib RMS (ISO 10816)', isHeader: true),
        _pdfCell('Cooling Fan & Shaft', isHeader: true),
      ];
    } else if (asset.type == AssetType.gearbox) {
      return [
        _pdfCell('Backlash / Endplay', isHeader: true),
        _pdfCell('Lube Oil Quality', isHeader: true),
        _pdfCell('Vib Peak (DE / NDE)', isHeader: true),
        _pdfCell('Shaft Seal & Hand Rot.', isHeader: true),
      ];
    } else if (asset.type == AssetType.pump) {
      return [
        _pdfCell('Discharge Head / Press', isHeader: true),
        _pdfCell('Flow Output Rate', isHeader: true),
        _pdfCell('Vib Velocity RMS', isHeader: true),
        _pdfCell('Mech Seal / Gland', isHeader: true),
      ];
    } else if (asset.type == AssetType.brake) {
      return [
        _pdfCell('Thruster Stroke', isHeader: true),
        _pdfCell('Lining Thickness', isHeader: true),
        _pdfCell('Braking Torque', isHeader: true),
        _pdfCell('Drum Clearance & Hold', isHeader: true),
      ];
    } else {
      return [
        _pdfCell('Torque / Thrust Test', isHeader: true),
        _pdfCell('Feedback (4-20mA)', isHeader: true),
        _pdfCell('Travel Time (sec)', isHeader: true),
        _pdfCell('Limit Switch & Handwheel', isHeader: true),
      ];
    }
  }

  static List<pw.Widget> _buildDiagnosticValues(AssetModel asset, bool isHealthy, bool wasTested) {
    final specs = asset.specs ?? {};

    if (!wasTested) {
      return [
        _pdfCell('Pending Test', isBold: false, color: PdfColors.grey700),
        _pdfCell('Pending Test', isBold: false, color: PdfColors.grey700),
        _pdfCell('Pending Test', isBold: false, color: PdfColors.grey700),
        _pdfCell('Pending Check', isBold: false, color: PdfColors.grey700),
      ];
    }

    if (asset.type == AssetType.motor) {
      final String irVal = asset.insulationResistance?['lowest'] != null
          ? '${asset.insulationResistance!['lowest']} M-Ohm'
          : (asset.insulationResistance?['R-E'] != null ? '${asset.insulationResistance!['R-E']} M-Ohm' : (isHealthy ? '> 50 M-Ohm (Pass)' : 'Pending Test'));
      final String windingVal = asset.windingResistance?['unbalance'] != null
          ? '${asset.windingResistance!['unbalance']}% Dev'
          : (isHealthy ? '< 1.5% Dev (Bal)' : 'Pending Test');
      final String vibVal = asset.vibration?['peak'] != null
          ? '${asset.vibration!['peak']} mm/s (Zone A)'
          : (isHealthy ? '< 1.8 mm/s (Pass)' : 'Pending Test');
      final String fanShaft = (specs['fanCondition'] != null && specs['shaftRotation'] != null)
          ? '${specs['fanCondition']} / ${specs['shaftRotation']}'
          : (isHealthy ? 'Clean / Smooth Rot.' : 'Pending Check');

      return [
        _pdfCell(irVal, isBold: true),
        _pdfCell(windingVal, isBold: true),
        _pdfCell(vibVal, isBold: true),
        _pdfCell(fanShaft, isBold: true),
      ];
    } else if (asset.type == AssetType.gearbox) {
      final String backlash = specs['backlash'] != null ? '${specs['backlash']} mm' : (isHealthy ? '0.12 mm (Normal)' : 'Pending Check');
      final String oilQuality = specs['oilLevelQuality']?.toString() ?? (asset.oilType != null ? '${asset.oilType}' : (isHealthy ? 'Clean & Full' : 'Pending Check'));
      final String vib = asset.vibration?['peak'] != null ? '${asset.vibration!['peak']} mm/s' : (isHealthy ? '< 2.0 mm/s (Pass)' : 'Pending Test');
      final String sealRot = (specs['oilSeal'] != null && specs['shaftRotation'] != null)
          ? '${specs['oilSeal']} / ${specs['shaftRotation']}'
          : (isHealthy ? 'Zero Leak / Smooth' : 'Pending Check');

      return [
        _pdfCell(backlash, isBold: true),
        _pdfCell(oilQuality, isBold: true),
        _pdfCell(vib, isBold: true),
        _pdfCell(sealRot, isBold: true),
      ];
    } else if (asset.type == AssetType.pump) {
      final String headVal = specs['head'] != null
          ? '${specs['head']} m'
          : (asset.head != null ? '${asset.head} m Head' : (isHealthy ? 'Rated Head (Pass)' : 'Pending Test'));
      final String flowVal = specs['flowRate'] != null
          ? '${specs['flowRate']} m3/h'
          : (asset.flowRate != null ? '${asset.flowRate} m3/h' : (isHealthy ? 'Rated Flow (Pass)' : 'Pending Test'));
      final String vib = asset.vibration?['peak'] != null ? '${asset.vibration!['peak']} mm/s' : (isHealthy ? '< 2.3 mm/s (Pass)' : 'Pending Test');
      final String seal = specs['sealStatus']?.toString() ?? (isHealthy ? 'Zero Leak (Pass)' : 'Pending Check');

      return [
        _pdfCell(headVal, isBold: true),
        _pdfCell(flowVal, isBold: true),
        _pdfCell(vib, isBold: true),
        _pdfCell(seal, isBold: true),
      ];
    } else if (asset.type == AssetType.brake) {
      final String stroke = specs['stroke'] != null ? '${specs['stroke']} mm' : (isHealthy ? '60 mm Stroke (Pass)' : 'Pending Check');
      final String lining = specs['lining'] != null ? '${specs['lining']} mm' : (isHealthy ? '10.5 mm (Normal)' : 'Pending Check');
      final String torque = specs['torque'] != null
          ? '${specs['torque']} Nm'
          : (asset.brakingTorqueNm != null ? '${asset.brakingTorqueNm} Nm' : (isHealthy ? 'Rated Torque (Pass)' : 'Pending Check'));
      final String clearanceHold = (specs['drumClearance'] != null && specs['holdingTest'] != null)
          ? '${specs['drumClearance']}mm (${specs['holdingTest']})'
          : (isHealthy ? '0.8 mm (Zero Slip)' : 'Pending Check');

      return [
        _pdfCell(stroke, isBold: true),
        _pdfCell(lining, isBold: true),
        _pdfCell(torque, isBold: true),
        _pdfCell(clearanceHold, isBold: true),
      ];
    } else {
      final String torque = specs['torque'] != null
          ? '${specs['torque']} Nm'
          : (asset.torqueOrThrust != null ? '${asset.torqueOrThrust} Nm/kN' : (isHealthy ? 'Rated Torque (Pass)' : 'Pending Check'));
      final String signal = specs['feedbackSignal']?.toString() ?? (asset.controlSignal ?? (isHealthy ? 'Linear 4-20mA' : 'Pending Check'));
      final String travelTime = specs['travelTime'] != null ? '${specs['travelTime']} sec' : (isHealthy ? '25 sec' : 'Pending Check');
      final String limitHand = (specs['limitSwitch'] != null && specs['handwheel'] != null)
          ? '${specs['limitSwitch']} / ${specs['handwheel']}'
          : (isHealthy ? 'Pass / Smooth Handwheel' : 'Pending Check');

      return [
        _pdfCell(torque, isBold: true),
        _pdfCell(signal, isBold: true),
        _pdfCell(travelTime, isBold: true),
        _pdfCell(limitHand, isBold: true),
      ];
    }
  }

  static pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
      child: pw.Center(
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: isHeader ? 4.8 : 5.2,
            fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? (isHeader ? PdfColors.grey800 : PdfColors.black),
          ),
        ),
      ),
    );
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
