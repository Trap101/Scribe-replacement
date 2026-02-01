import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/report_model.dart';
import '../models/form_field_model.dart';

class PdfExportService {
  Future<Uint8List> generateReport(ParamedicReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(report),
        build: (context) => [
          for (final section in report.sections) ...[
            _buildSectionHeader(section.title),
            _buildSectionFields(section),
            pw.SizedBox(height: 12),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(ParamedicReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('PARAMEDIC PATIENT REPORT',
            style:
                pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('Report ID: ${report.reportId}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Created: ${report.createdAt.toString().substring(0, 16)}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: PdfColors.blue50,
      child: pw.Text(title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildSectionFields(FormSection section) {
    return pw.Wrap(
      children: section.fields.map((field) {
        if (field.type == FieldType.tick) {
          return pw.Container(
            width: 180,
            padding: const pw.EdgeInsets.all(4),
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: 12,
                  height: 12,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                  ),
                  child: field.value == true
                      ? pw.Center(
                          child: pw.Text('X',
                              style: const pw.TextStyle(fontSize: 9)))
                      : pw.SizedBox(),
                ),
                pw.SizedBox(width: 4),
                pw.Expanded(
                    child: pw.Text(field.label,
                        style: const pw.TextStyle(fontSize: 9))),
              ],
            ),
          );
        }
        return pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(field.label,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
                ),
                child: pw.Text(
                  field.value?.toString() ?? '',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
