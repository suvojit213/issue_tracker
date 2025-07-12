import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart'; // Added for Excel generation

class ReportGenerator {
  static Future<File> generatePdfReport(List<String> issueHistory, DateTime? date) async {
    final pdf = pw.Document();

    String dateText = '';
    if (date != null) {
      dateText = ' for ${date.day}/${date.month}/${date.year}';
    } else {
      dateText = ' (All History)';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Daily Issue Report' + dateText,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'CRM ID',
                'TL Name',
                'Advisor Name',
                'Organization',
                'Issue Explanation',
                'Reason',
                'Start Time',
                'End Time',
                'Fill Time',
                'Issue Remarks',
              ],
              data: issueHistory.map((entry) {
                final parts = _parseIssueEntry(entry);
                return [
                  parts['CRM ID'] ?? '',
                  parts['TL Name'] ?? '',
                  parts['Advisor Name'] ?? '',
                  parts['Organization'] ?? '',
                  parts['Issue Explanation'] ?? '',
                  parts['Reason'] ?? '',
                  parts['Start Time'] ?? '',
                  parts['End Time'] ?? '',
                  parts['Fill Time'] ?? '',
                  parts['Issue Remarks'] ?? '',
                ];
              }).toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(4),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2), // CRM ID
                1: const pw.FlexColumnWidth(1.8), // TL Name
                2: const pw.FlexColumnWidth(1.5), // Advisor Name
                3: const pw.FlexColumnWidth(1.2), // Organization
                4: const pw.FlexColumnWidth(2.5), // Issue Explanation
                5: const pw.FlexColumnWidth(1.8), // Reason
                6: const pw.FlexColumnWidth(1.5), // Start Time
                7: const pw.FlexColumnWidth(1.5), // End Time
                8: const pw.FlexColumnWidth(1.5), // Fill Time
                9: const pw.FlexColumnWidth(2.5), // Issue Remarks
              },
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/issue_report_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> generateXlsxReport(List<String> issueHistory, DateTime? date) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    String dateText = '';
    if (date != null) {
      dateText = ' for ${date.day}/${date.month}/${date.year}';
    } else {
      dateText = ' (All History)';
    }

    // Add title row
    sheetObject.insertRowIterables([TextCellValue('Daily Issue Report' + dateText)], 0);
    // sheetObject.mergeCells(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0));

    // Add headers
    List<String> headers = [
      'CRM ID',
      'TL Name',
      'Advisor Name',
      'Organization',
      'Issue Explanation',
      'Reason',
      'Start Time',
      'End Time',
      'Fill Time',
      'Issue Remarks',
    ];
    sheetObject.insertRowIterables(headers.map((e) => TextCellValue(e)).toList(), 1);

    // Add data
    for (int i = 0; i < issueHistory.length; i++) {
      final parts = _parseIssueEntry(issueHistory[i]);
      List<String> rowData = [
        parts['CRM ID'] ?? '',
        parts['TL Name'] ?? '',
        parts['Advisor Name'] ?? '',
        parts['Organization'] ?? '',
        parts['Issue Explanation'] ?? '',
        parts['Reason'] ?? '',
        parts['Start Time'] ?? '',
        parts['End Time'] ?? '',
        parts['Fill Time'] ?? '',
        parts['Issue Remarks'] ?? '',
      ];
      sheetObject.insertRowIterables(rowData.map((e) => TextCellValue(e)).toList(), i + 2);
    }

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/issue_report_${DateTime.now().millisecondsSinceEpoch}.xlsx");
    await file.writeAsBytes(excel.encode()!);
    return file;
  }

  static Map<String, String> _parseIssueEntry(String entry) {
    final Map<String, String> parsed = {};
    final parts = entry.split(', ');
    for (var part in parts) {
      final keyValue = part.split(': ');
      if (keyValue.length == 2) {
        parsed[keyValue[0]] = keyValue[1];
      }
    }
    return parsed;
  }
}
