import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
  excel.rename(defaultSheet, 'Motors');
  
  final motorSheet = excel['Motors'];
  final brakeSheet = excel['Brakes'];

  // 1. MOTORS SHEET
  final motorHeaders = [
    'type', 'name', 'status', 'make', 'model', 'serialNo', 'powerKw', 'voltage', 'speedRpm',
    'fullLoadCurrent', 'frameSize', 'bearingDE', 'bearingNDE', 'couplingAvailable', 'spareLocation',
    'installationDate', 'seqNo',
  ];
  motorSheet.appendRow(motorHeaders.map((h) => TextCellValue(h)).toList());

  final motorRows = [
    ['motor', 'BF-1 HMC 60 T Main Hoist Motor', 'active', 'GEC', '', '883/353', '15.7', '415', '735', '35', '200L', 'NU 312 ECM C3', '6312', 'YES', 'WS HMH M Area', '2026-06-26', '001'],
    ['motor', 'BF-1 HMC 60 T CT Drive Motor', 'active', 'GEC', '', '517/483', '23', '415', '950', '45', '200L', 'NU312', 'NU312', 'YES', 'WS HMH M Area', '2026-06-04', '002'],
    ['motor', 'BF-1 HMC 10 T CT Drive Motor', 'active', 'NGEF', '', '17', '3.7', '415', '1440', '7.3', '112M', '6306 2RSC3', '6206 2RSC3', 'YES', 'WS HMH M Area', '2026-06-11', '003'],
    ['motor', 'BF-1 HMC 10 T CT Drive Motor (Low Power)', 'active', 'NGEF', '', '305', '1.1', '415', '1400', '2.5', '90S', '62052RSC3', '6205 2RSC3', 'YES', 'WS HMH M Area', '2026-06-12', '004'],
    ['motor', 'BF-1 HMC Long Travel (LT) Motor', 'active', 'GEC', '', '517', '23', '415', '960', '45', '200L', 'NU312', '6312', 'YES', 'WS HMH M Area', '2026-06-11', '005'],
    ['motor', 'BF-2 HMC 60 T Main Hoist Motor', 'active', 'Siemens', '', '933', '25', '415', '876', '48', '200L', '6312-2ZC3', '6312-2ZC3', 'YES', 'WS HMH M Area', '2026-05-06', '006'],
    ['motor', 'BF-2 HMC 10 T Aux Hoist Motor', 'active', 'Siemens', '', '939', '6.3', '415', '956', '14', '132M', '6208-2ZC3', '6206-2ZC3', 'YES', 'WS HMH M Area', '2026-05-06', '007'],
    ['motor', 'BF-2 HMC 60 T CT Drive Motor', 'active', 'Siemens', '', '939', '6.3', '415', '956', '14', '132M', '6208-2ZC3', '6206-2ZC3', 'YES', 'WS HMH M Area', '2026-05-06', '008'],
    ['motor', 'BF-2 HMC 10 T CT Drive Motor', 'active', 'Siemens', '', '923', '1.4', '415', '906', '3.3', '90L', '6205-2Z', '6204-2Z', 'YES', 'WS HMH M Area', '2026-05-06', '009'],
    ['motor', 'BF-2 HMC Long Travel (LT) Motor', 'active', 'Siemens', '', '937', '14', '415', '967', '28', '160L', '6309-2ZC3', '6309-2ZC3', 'YES', 'WS HMH M Area', '2026-05-06', '010'],
    ['motor', 'Baghouse Crane 30 T Hoist Motor', 'active', 'Siemens', '', '934', '34', '415', '975', '56', '225M', '6313-C3', '6313-C3', 'YES', 'WS HMH M Area', '2026-05-06', '011'],
    ['motor', 'Baghouse Crane 12 T Hoist Motor', 'active', 'Siemens', '', '935', '51', '415', '982', '80', '280S', '6317-C3', '6317-C3', 'YES', 'WS HMH M Area', '2026-05-06', '012'],
    ['motor', 'Baghouse Crane CT Drive Motor', 'active', 'Siemens', '', '936', '9', '415', '955', '16', '160M', '6309-2ZC3', '6309-2ZC3', 'YES', 'WS HMH M Area', '2026-05-06', '013'],
    ['motor', 'Baghouse Crane Long Travel (LT) Motor', 'active', 'Siemens', '', '932/931', '17', '415', '970', '29', '180L', '6310-2ZC3', '6310-2ZC3', 'YES', 'WS HMH M Area', '2026-05-06', '014'],
    ['motor', 'BF-1/2 SGC Hoist/Lower Motor', 'active', 'Siemens', '', '930', '15', '415', '976', '24', '200L', '6310-2ZC3', '6310-2ZC3', 'YES', 'WS HMH M Area', '2026-05-06', '015'],
    ['motor', 'BF-1/2 SGC Open/Close Motor', 'active', 'Siemens', '', '930', '15', '415', '976', '24', '200L', '6310-2ZC3', '6310-2ZC3', 'YES', 'WS HMH M Area', '2026-05-06', '016'],
    ['motor', 'BF-1/2 SGC Cross Travel (CT) Motor', 'active', 'Siemens', '', '908', '0.55', '415', '916', '3.2', '90D', '6204-2ZC3', '6204-2ZC3', 'NO', 'WS HMH M Area', '2026-06-29', '017'],
    ['motor', 'BF-1/2 SGC Long Travel (LT) Motor', 'active', 'Siemens', '', '940', '4.5', '415', '953', '10', '132S', '6208-2ZC3', '6208-2ZC3', 'NO', 'WS HMH M Area', '2026-05-06', '018'],
    ['motor', 'BF-1/2 C/H Crane Hoist Motor', 'active', 'KIRLOSKAR', '', '', '10', '415', '960', '21.2', 'PB160L', '6309', '6309', 'YES', 'WS HMH M Area', '2026-06-12', '019'],
    ['motor', 'BF-1/2 Runner Cooling Fan Motor', 'active', 'CG', '', '', '0.55', '415', '910', '1.7', 'ND85D', '6204ZZ', '6204ZZ', 'NO', 'WS HMH M Area', '2026-05-29', '020'],
    ['motor', 'LHC Hoist Motor', 'active', 'Siemens', '', '', '22', '415', '1473', '38', '180L', '63102ZC3', '63102ZC3', 'NO', 'WS HMH M Area', '2026-03-29', '021'],
    ['motor', 'LHC Cross Travel Motor', 'active', 'Siemens', '', '', '22', '415', '1473', '38', '180L', '63102ZC3', '63102ZC3', 'NO', 'WS HMH M Area', '2026-03-29', '022'],
    ['motor', 'PCM 2/3 Main Drive Motor', 'active', 'ABB', '', '152', '22', '415', '1464', '42', '180L', '63102ZC3', '63102ZC3', 'YES', 'WS HMH M Area', '2026-05-29', '023'],
    ['motor', 'PCM 2/3 Lime Pump 1 Motor', 'active', 'NGEF', '', '', '2.2', '415', '1400', '4.6', '100L', '6206Z', '6206Z', 'NO', 'WS HMH M Area', '2026-06-17', '024'],
    ['motor', 'PCM 2/3 Lime Stirrer 1 Motor', 'active', 'REMI', '', '', '1.5', '415', '940', '3.6', '90L', '6204ZZ', '6204ZZ', 'NO', 'WS HMH M Area', '2026-06-05', '025'],
    ['motor', 'PCM 2/3 Lime Stirrer 2 Motor', 'active', 'REMI', '', '', '1.5', '415', '940', '3.6', '90L', '6204ZZ', '6204ZZ', 'NO', 'WS HMH M Area', '2026-07-08', '026'],
    ['motor', 'PCM 4 Lime Pump Motor', 'active', 'Siemens', '', '', '3.7', '415', '1400', '4.6', '112L', '6206Z', '6206Z', 'NO', 'WS HMH M Area', '2026-06-20', '027'],
    ['motor', 'PCM 4 Lime Stirrer 1 Motor', 'active', 'REMI', '', '', '1.5', '415', '940', '3.6', '90L', '6204ZZ', '6204ZZ', 'NO', 'WS HMH M Area', '2026-06-05', '028'],
    ['motor', 'PCM 4 Lime Stirrer 2 Motor', 'active', 'REMI', '', '', '1.5', '415', '940', '3.6', '90L', '6204ZZ', '6204ZZ', 'NO', 'WS HMH M Area', '2026-06-08', '029'],
    ['motor', 'PCM 4 Main Drive Motor', 'active', 'Siemens', '', '318', '11', '415', '1445', '21', '160M', '6209C3', '6209C3', 'YES', 'WS HMH M Area', '2026-06-05', '030'],
    ['motor', 'PCM 2/3/4 Monorail Crane Swivel Motor', 'active', 'EDDY', '', '467', '0.37', '415', '950', '0.9', '', '', '', 'NO', 'WS HMH M Area', '2026-06-08', '031'],
    ['motor', 'PCM 2/3/4 Monorail Crane Hoist Motor', 'active', 'EDDY', '', '', '6.5', '415', '950', '11', '', '', '', 'NO', 'WS HMH M Area', '', '032'],
    ['motor', 'PCM 2/3/4 Monorail Crane CT Motor', 'active', 'EDDY', '', '470', '2.2', '415', '950', '4.5', '', '', '', 'NO', 'WS HMH M Area', '2026-06-06', '033'],
    ['motor', 'LDC ID Fan Motor', 'active', 'ABB', '', '', '132', '415', '994', '239', '315L', '6319 C3', '6316 C3', 'NO', 'WS HMH M Area', '2026-03-30', '034'],
    ['motor', 'LDC Compressor Motor', 'active', '', '', '', '7.5', '415', '', '', '', '', '', 'NO', 'WS HMH M Area', '', '035'],
    ['motor', 'LDC Screw Conveyor Motor', 'active', 'REMI', '', '566', '1.1', '415', '1440', '2.5', 'NZ290S 214', '6202ZZ', '6202ZZ', 'NO', 'WS HMH M Area', '2026-06-11', '036'],
    ['motor', 'LDC Rotary Air Lock Valve (RAV) Motor', 'active', 'REMI', '', '568', '0.75', '415', '960', '2.0', 'NZ280M 1/4', '6202ZZ', '6202ZZ', 'NO', 'WS HMH M Area', '2026-06-11', '037'],
    ['motor', 'DS ID Hood Drive Motor', 'active', 'Siemens', '', '', '30', '415', '1480', '52', '200L', '6312C3', '6212C3', 'NO', 'WS HMH M Area', '2026-05-21', '038'],
    ['motor', 'DS Car (Winch) Motor', 'active', 'Siemens', '', '860', '3.7', '415', '940', '7.6', '132S', '6208ZZ', '6207ZZ', 'NO', 'WS HMH M Area', '2026-06-12', '039'],
    ['motor', 'DS Hydraulic Powerpack Pump Motor', 'active', 'Siemens', '', '', '5.5', '415', '1455', '11.7', 'KD132S', '6208ZZ', '6207ZZ', 'NO', 'WS CS M Area', '2026-06-08', '040'],
    ['motor', 'DS Screw Conveyor Motor', 'active', 'ROTOMOTIVE', '', '890', '2.2', '415', '1400', '4.5', '100L', '6206ZZ', '6206ZZ', 'NO', 'WS HMH M Area', '2026-05-29', '041'],
    ['motor', 'DS FD/BH RAV Motor', 'active', 'CG', '', '926', '0.37', '415', '1390', '1.0', '', '6202ZZ', '6202ZZ', 'NO', 'WS HMH M Area', '2026-05-29', '042'],
    ['motor', 'LTC Compressor Motor', 'active', 'Siemens', '', '868', '45', '415', '960', '98', 'ND200L', '6312ZZC4', '6312ZZC4', 'NO', 'WS HMH M Area', '', '043'],
    ['motor', 'LTC Cross Travel (CT) Motor', 'active', 'Siemens', '', '', '4.5', '415', '953', '10', '132S', '6208-2ZC3', '6208-2ZC3', 'NO', 'WS HMH M Area', '2026-06-11', '044'],
    ['motor', 'Ladle Tilter Recirculation Pump Motor', 'active', 'ABB', '', '', '1.1', '415', '1450', '', '180', '62052ZC3', '62042ZC3', 'YES', 'WS HMH M Area', '2026-05-15', '045'],
    ['motor', 'Ladle Tilter Hydraulic Powerpack Pump Motor 1', 'active', 'ABB', '', '', '18.5', '415', '1480', '', '', '62052ZC3', '62042ZC3', 'YES', 'WS HMH M Area', '2026-06-11', '046'],
    ['motor', 'Ladle Tilter Hydraulic Powerpack Pump Motor 2', 'active', 'Beide', '', '', '55', '415', '1480', '94', '250M-4', '6313ZC3', '6314ZZ', 'NO', 'WS BLP M Area', '2026-06-29', '047'],
    ['motor', 'BF-1/2 MG DM PP Recirculation Pump Motor', 'active', 'Beide', '', '', '4', '415', '1460', '7.8', '', '', '', 'NO', 'WS HMH M Area', '2026-06-01', '048'],
    ['motor', 'Common Thruster Motor 18 Kg', 'spare', 'Ster/Soc', '', '', '0.15', '415', '', '', '', '', '', 'NO', 'WS HMH M Area', '2026-06-01', '049'],
    ['motor', 'Common Thruster Motor 34 Kg', 'spare', 'Ster/Soc', '', '', '0.09', '415', '', '', '', '', '', 'NO', 'WS HMH M Area', '2026-06-01', '050'],
  ];

  for (var row in motorRows) {
    motorSheet.appendRow(row.map((val) => TextCellValue(val)).toList());
  }

  // 2. BRAKES SHEET
  final brakeHeaders = [
    'type', 'name', 'status', 'brakeType', 'make', 'model', 'serialNo', 'voltageType', 'voltageRating',
    'thrusterCapacityKg', 'drumDiaMm', 'drumWidthMm', 'drumInstallation', 'mountingBoltSize',
    'noOfMountingBolts', 'mountingLengthMm', 'mountingWidthMm', 'seqNo',
  ];
  brakeSheet.appendRow(brakeHeaders.map((h) => TextCellValue(h)).toList());

  final brakeRows = [
    ['brake', 'BF-1 HMC 60 T Hoist Brake (2 Nos)', 'active', 'Electromagnetic', 'BCH', '', '', 'DC', '110', '', '250', '120', '1-M 1-GB', 'M12', '4', '210', '165', '001'],
    ['brake', 'BF-1 HMC 10 T Hoist Brake', 'active', 'Electromagnetic', 'BCH', '', '', 'DC', '110', '', '200', '100', 'GB', 'M12', '4', '350', '65', '002'],
    ['brake', 'BF-1 HMC 60 T CT Brake', 'active', 'Electromagnetic', 'BCH', '', '', 'DC', '110', '', '200', '100', 'GB', 'M12', '4', '165', '145', '003'],
    ['brake', 'BF-1 HMC LT Thruster Brake', 'active', 'Thruster', 'Sterling', '', '', 'AC', '415', '18', '250', '130', 'GB', 'M12', '4', '490', '120', '004'],
    ['brake', 'BF-2 HMC 60 T Hoist Brake (2 Nos)', 'active', 'Electromagnetic', 'BCH', '', '', 'DC', '110', '', '250', '120', '1-M 1-GB', 'M12', '4', '210', '165', '005'],
    ['brake', 'BF-2 HMC 10 T Hoist Brake', 'active', 'Electromagnetic', 'BCH', '', '', 'DC', '110', '', '200', '100', 'GB', 'M12', '4', '350', '65', '006'],
    ['brake', 'BF-2 HMC 60 T CT Brake', 'active', 'Electromagnetic', 'BCH', '', '', 'DC', '110', '', '200', '100', 'GB', 'M12', '4', '350', '65', '007'],
    ['brake', 'BF-2 HMC 10 T CT Brake (2 Nos)', 'active', 'Electromagnetic', 'BCH', '', '', 'DC', '110', '', '200', '100', 'GB', 'M12', '4', '350', '65', '008'],
    ['brake', 'BF-2 HMC LT Brake (2 Nos)', 'active', 'Electromagnetic', 'BCH', '', '', 'DC', '110', '', '200', '100', 'GB', 'M12', '4', '350', '65', '009'],
    ['brake', 'Baghouse Crane 30 T Hoist Thruster Brake (2 Nos)', 'active', 'Thruster', 'Sterling', '', '', 'AC', '415', '34', '300', '150', 'GB', 'M12', '4', '680', '120', '010'],
    ['brake', 'Baghouse Crane 12 T Hoist Thruster Brake', 'active', 'Thruster', 'Sterling', '', '', 'AC', '415', '34', '400', '190', 'GB', 'M16', '6', '855', '165', '011'],
    ['brake', 'Baghouse Crane CT Thruster Brake (2 Nos)', 'active', 'Thruster', 'Sterling', '', '', 'AC', '415', '18', '160', '80', 'GB', 'M10', '4', '410', '68', '012'],
    ['brake', 'Baghouse Crane LT Thruster Brake', 'active', 'Thruster', 'Sterling', '', '', 'AC', '415', '34', '250', '130', 'GB', 'M12', '6', '550', '100', '013'],
    ['brake', 'BF-1/2 SGC C/C Thruster Brake', 'active', 'Thruster', 'Sterling', '', '', 'AC', '415', '18', '200', '100', 'GB', 'M10', '6', '550', '100', '014'],
    ['brake', 'BF-1/2 SGC CT/LT Thruster Brake', 'active', 'Thruster', 'Sterling', '', '', 'AC', '415', '18', '160', '80', 'GB', 'M10', '4', '360', '60', '015'],
    ['brake', 'BF-1/2 C/H Crane Hoist Brake', 'active', 'Electromagnetic', 'EMCO', '', '', 'DC', '190', '', '260', '', 'M', '', '', '', '', '016'],
    ['brake', 'DS Hood Thruster Brake', 'active', 'Thruster', 'Sterling', '', '', 'AC', '415', '18', '160', '80', 'GB', 'M10', '4', '410', '68', '017'],
    ['brake', 'LTC CT Thruster Brake', 'active', 'Thruster', 'Sterling', '', '', 'AC', '415', '18', '160', '80', 'GB', 'M10', '4', '410', '68', '018'],
  ];

  for (var row in brakeRows) {
    brakeSheet.appendRow(row.map((val) => TextCellValue(val)).toList());
  }

  final bytes = excel.save();
  if (bytes != null) {
    File('Plant_Assets_Ready_To_Import.xlsx').writeAsBytesSync(bytes);
    print('Generated Plant_Assets_Ready_To_Import.xlsx with ${motorRows.length} Motors and ${brakeRows.length} Brakes.');
  }
}
