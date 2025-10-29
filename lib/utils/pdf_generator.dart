import 'dart:io';
import 'package:flutter/material.dart'; // FontWeight, FontStyle, TextAlign
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> generatePDF({
  required String text,
  required String pageSize,
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.normal,
  FontStyle fontStyle = FontStyle.normal,
  TextAlign alignment = TextAlign.left,
  String fileName = "", // optional rename
}) async {
  final pdf = pw.Document();

  // Page size selection
  final PdfPageFormat pdfPageFormat;
  switch (pageSize) {
    case "legal":
      pdfPageFormat = const PdfPageFormat(8.5 * PdfPageFormat.inch, 14 * PdfPageFormat.inch);
      break;
    case "a4":
      pdfPageFormat = PdfPageFormat.a4;
      break;
    default:
      pdfPageFormat = PdfPageFormat.letter;
  }

  // Map styles
  final pwFontWeight =
      fontWeight == FontWeight.bold ? pw.FontWeight.bold : pw.FontWeight.normal;
  final pwFontStyle =
      fontStyle == FontStyle.italic ? pw.FontStyle.italic : pw.FontStyle.normal;

  pw.TextAlign pwAlignment = pw.TextAlign.left;
  if (alignment == TextAlign.center) pwAlignment = pw.TextAlign.center;
  if (alignment == TextAlign.right) pwAlignment = pw.TextAlign.right;
  if (alignment == TextAlign.justify) pwAlignment = pw.TextAlign.justify;

  pdf.addPage(
    pw.Page(
      pageFormat: pdfPageFormat,
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(40), // add real margins
          child: pw.Text(
            text,
            textAlign: pwAlignment,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pwFontWeight,
              fontStyle: pwFontStyle,
            ),
          ),
        );
      },
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final sanitizedFileName = fileName.isEmpty
    ? "Document_${DateTime.now().millisecondsSinceEpoch}"
    : fileName;
  final file = File("${dir.path}/$sanitizedFileName.pdf");
  await file.writeAsBytes(await pdf.save());
}
