// docx_generator.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

/// Generate a DOCX file from HTML/editor content or plain text
/// Supports: bold, italic, underline, alignment, font, fontSize, page size
Future<File?> generateDocx({
  required String text,
  required BuildContext context,
  String fontFamily = "Calibri",
  int fontSize = 24,
  String pageSize = "A4",
  bool bold = false,
  bool italic = false,
  bool underline = false,
  TextAlign alignment = TextAlign.left,
  String fileName = "", // optional, user can rename later
}) async {
  try {
    // ------------------------
    // 1️⃣ Map page size
    // ------------------------
    int pageWidth = 11906; // A4 default
    int pageHeight = 16838;

    switch (pageSize.toLowerCase()) {
      case "short":
        pageHeight = 14000;
        break;
      case "long":
        pageHeight = 20000;
        break;
    }

    // ------------------------
    // 2️⃣ Parse HTML content if any
    // ------------------------
    List<String> paragraphs = [];
    bool isHtml = text.trim().startsWith("<");

    if (isHtml) {
      dom.Document doc = html_parser.parse(text);

      for (var p in doc.getElementsByTagName('p')) {
        String align = "left";
        if (p.attributes.containsKey('style')) {
          final style = p.attributes['style']!.toLowerCase();
          if (style.contains("center")) align = "center";
          if (style.contains("right")) align = "right";
        }

        List<String> runs = [];
        final spans = p.getElementsByTagName('span');
        if (spans.isEmpty) {
          // If no spans, treat p.text as a single run
          final plain = p.text.replaceAll("\n", " ").trim();
          if (plain.isNotEmpty) {
            runs.add(_buildRun(
              plain,
              fontFamily,
              fontSize,
              bold,
              italic,
              underline,
            ));
          }
        } else {
          for (var span in spans) {
            String spanText = span.text.replaceAll("\n", " ").trim();
            if (spanText.isEmpty) continue;

            bool spanBold = bold, spanItalic = italic, spanUnderline = underline;
            String runFont = fontFamily;
            int runSize = fontSize;

            if (span.attributes.containsKey('style')) {
              final style = span.attributes['style']!.toLowerCase();
              if (style.contains("bold")) spanBold = true;
              if (style.contains("italic")) spanItalic = true;
              if (style.contains("underline")) spanUnderline = true;

              final sizeMatch = RegExp(r'font-size\s*:\s*(\d+)').firstMatch(style);
              if (sizeMatch != null) runSize = int.parse(sizeMatch.group(1)!) * 2;

              final fontMatch = RegExp(r'font-family\s*:\s*([^;]+)').firstMatch(style);
              if (fontMatch != null) runFont = fontMatch.group(1)!.replaceAll('"', '').trim();
            }

            runs.add(_buildRun(spanText, runFont, runSize, spanBold, spanItalic, spanUnderline));
          }
        }

        paragraphs.add('<w:p><w:pPr><w:jc w:val="$align"/></w:pPr>${runs.join()}</w:p>');
      }
    } else {
      // Treat as plain text
      for (var para in text.split(RegExp(r'\n{2,}'))) {
        final lines = para.split('\n');
        String runs = lines.map((line) {
          line = line.trim();
          if (line.isEmpty) line = " ";
          return _buildRun(line, fontFamily, fontSize, bold, italic, underline);
        }).join('<w:br/>'); // preserve line breaks
        paragraphs.add('<w:p><w:pPr><w:jc w:val="${_alignmentToString(alignment)}"/></w:pPr>$runs</w:p>');
      }
    }

    // ------------------------
    // 3️⃣ Wrap in document.xml
    // ------------------------
    String documentXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${paragraphs.join()}
    <w:sectPr>
      <w:pgSz w:w="$pageWidth" w:h="$pageHeight"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>
''';

    // ------------------------
    // 4️⃣ Prepare other required DOCX files
    // ------------------------
    final files = <String, List<int>>{
      '[Content_Types].xml': _contentTypesXml.codeUnits,
      '_rels/.rels': _relsRels.codeUnits,
      'word/_rels/document.xml.rels': _wordRels.codeUnits,
      'word/document.xml': documentXml.codeUnits,
    };

    // ------------------------
    // 5️⃣ Build DOCX ZIP
    // ------------------------
    final archive = Archive();
    files.forEach((name, bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });

    final docxBytes = ZipEncoder().encode(archive);

    // ------------------------
    // 6️⃣ Save file
    // ------------------------
    final dir = await getApplicationDocumentsDirectory();
    final sanitizedFileName = fileName.isEmpty
        ? "Document_${DateTime.now().millisecondsSinceEpoch}"
        : fileName;
    final filePath = '${dir.path}/$sanitizedFileName.docx';

    final file = File(filePath);
    await file.writeAsBytes(docxBytes!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved DOCX at: $filePath")),
    );

    await OpenFile.open(filePath);
    return file;
  } catch (e) {
    print("Error generating DOCX: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error generating DOCX: $e")),
    );
    return null;
  }
}

// ------------------------
// Helper to build <w:r> with styles
// ------------------------
String _buildRun(String text, String font, int size, bool bold, bool italic, bool underline) {
  return '<w:r><w:rPr>'
      '${bold ? "<w:b/>" : ""}'
      '${italic ? "<w:i/>" : ""}'
      '${underline ? "<w:u w:val=\"single\"/>" : ""}'
      '<w:rFonts w:ascii="$font"/>'
      '<w:sz w:val="$size"/>'
      '</w:rPr><w:t>${_escapeXml(text)}</w:t></w:r>';
}

String _alignmentToString(TextAlign align) {
  switch (align) {
    case TextAlign.center:
      return "center";
    case TextAlign.right:
      return "right";
    case TextAlign.justify:
      return "both";
    case TextAlign.left:
    default:
      return "left";
  }
}

// ------------------------
// Escape XML special characters
// ------------------------
String _escapeXml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

// ------------------------
// Required static DOCX files
// ------------------------
const String _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
''';

const String _relsRels = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
''';

const String _wordRels = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
''';
