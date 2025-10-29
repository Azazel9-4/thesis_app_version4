import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/pagination_manager.dart';
import '../services/print_view.dart';
import '../services/mobile_view.dart';
import '../utils/docx_generator.dart';
import '../utils/pdf_generator.dart';

class StyledText {
  String text;
  bool bold;
  bool italic;
  bool underline;
  TextAlign alignment;
  double fontSize;
  String fontFamily;

  StyledText(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.alignment = TextAlign.left,
    this.fontSize = 14,
    this.fontFamily = 'Arial',
  });
}


class TextEditorScreen extends StatefulWidget {
  final String? initialText;
  final String? fileName;
  
  const TextEditorScreen({super.key, this.initialText, this.fileName});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final PaginationManager _paginationManager = PaginationManager();
  bool _isPrintView = false;
  bool _isHTMLView = false;
  bool _showFormattingToolbar = true;

  // Formatting states
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  TextAlign _alignment = TextAlign.left;
  double _fontSize = 14;
  String _fontFamily = 'Arial';
  PaperSize _pageSize = PaperSize.a4;

  @override
  void initState() {
    super.initState();
    _paginationManager.initialize();
    if (_paginationManager.pages.isEmpty) _paginationManager.loadInitialText('');

    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      final looksLikeHTML = widget.initialText!.contains("<p") ||
          widget.initialText!.contains("<span");
      if (looksLikeHTML) {
        _isHTMLView = false;
        final plainText = _stripHtmlTags(widget.initialText!);
        _paginationManager.loadInitialText(plainText);
      } else {
        _paginationManager.loadInitialText(widget.initialText!);
      }
    }

    _paginationManager.addListener(() => setState(() {}));
  }

  String _stripHtmlTags(String html) {
    final tagRegExp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return html.replaceAll(tagRegExp, '').trim();
  }

  void _toggleView() {
    setState(() {
      _isPrintView = !_isPrintView;
      _isHTMLView = false;
    });
  }

  // ignore: unused_element
  void _toggleHTMLView() {
    setState(() {
      _isHTMLView = !_isHTMLView;
    });
  }

  void _toggleFormattingToolbar() {
    setState(() => _showFormattingToolbar = !_showFormattingToolbar);
  }

  Future<void> _saveDocument() async {
    final allText = _paginationManager.pages.map((page) => page.map((s) => s.text).join('\n')).join('\n\n');

  TextEditingController fileNameController = TextEditingController(
      text: widget.fileName ?? 'Document_${DateTime.now().millisecondsSinceEpoch}');


    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fileNameController,
              decoration: const InputDecoration(labelText: 'File name'),
            ),
            const SizedBox(height: 12),
            const Text('Choose file format to save:'),
          ],
        ),
        actions: [
          // DOCX
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final fileName = fileNameController.text.trim();
              if (fileName.isEmpty) return;

              String pageSizeString = _pageSize.name;

              try {
                  final file = await generateDocx(
                    text: allText,
                    context: context,
                    fontSize: _fontSize.toInt(),
                    fontFamily: _fontFamily,
                    pageSize: pageSizeString,
                    fileName: fileName, // <-- add this
                  );

                if (file != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved DOCX:\n${file.path}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving DOCX: $e')),
                );
              }
            },
            child: const Text('DOCX'),
          ),

          // PDF
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final fileName = fileNameController.text.trim();
              if (fileName.isEmpty) return;

              FontWeight fontWeight = _isBold ? FontWeight.bold : FontWeight.normal;
              FontStyle fontStyle = _isItalic ? FontStyle.italic : FontStyle.normal;
              TextAlign alignment = _alignment;

              try {
                  await generatePDF(
                    text: allText,
                    pageSize: _pageSize.name,
                    fontSize: _fontSize,
                    fontWeight: fontWeight,
                    fontStyle: fontStyle,
                    alignment: alignment,
                    fileName: fileName, // <-- add this
                  );


                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved PDF in documents folder')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving PDF: $e')),
                );
              }
            },
            child: const Text('PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingToolbar() {
    if (!_showFormattingToolbar) return const SizedBox.shrink();
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isBold ? Icons.format_bold : Icons.format_bold_outlined, color: _isBold ? Colors.blue : Colors.black,),
              onPressed: () => setState(() => _isBold = !_isBold),
              tooltip: 'Bold',
            ),
            IconButton(
              icon: Icon(_isItalic ? Icons.format_italic : Icons.format_italic_outlined, color: _isItalic ? Colors.blue : Colors.black,),
              onPressed: () => setState(() => _isItalic = !_isItalic),
              tooltip: 'Italic',
            ),
            IconButton(
              icon: Icon(_isUnderline
                  ? Icons.format_underline
                  : Icons.format_underline_outlined, color: _isUnderline ? Colors.blue : Colors.black,),
              onPressed: () => setState(() => _isUnderline = !_isUnderline),
              tooltip: 'Underline',
            ),
            const SizedBox(width: 12),
          DropdownButton<TextAlign>(
            value: _alignment,
            items: [
              DropdownMenuItem(
                  value: TextAlign.left,
                  child: Icon(Icons.format_align_left, color: Colors.black)),
              DropdownMenuItem(
                  value: TextAlign.center,
                  child: Icon(Icons.format_align_center, color: Colors.black)),
              DropdownMenuItem(
                  value: TextAlign.right,
                  child: Icon(Icons.format_align_right, color: Colors.black)),
              DropdownMenuItem(
                  value: TextAlign.justify,
                  child: Icon(Icons.format_align_justify, color: Colors.black)),
            ],
            onChanged: (v) => setState(() => _alignment = v ?? TextAlign.left),
            underline: Container(),
            iconSize: 20,
            iconEnabledColor: Colors.black,
            dropdownColor: Colors.white, // <-- added
          ),
          const SizedBox(width: 12),

          DropdownButton<double>(
            value: _fontSize,
            items: [12, 14, 16, 18, 20, 24, 28, 32].map((f) {
              final isSelected = _fontSize == f.toDouble();
              return DropdownMenuItem(
                value: f.toDouble(),
                child: Text(
                  '$f',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? const Color.fromARGB(255, 0, 0, 0) : const Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _fontSize = v ?? 14),
            underline: Container(),
            iconSize: 20,
            iconEnabledColor: const Color.fromARGB(255, 0, 0, 0),
            dropdownColor: const Color.fromARGB(255, 255, 255, 255), // <-- added
          ),
          const SizedBox(width: 12),

          DropdownButton<String>(
            value: _fontFamily,
            items: ['Arial', 'Times New Roman', 'Calibri', 'Courier New']
                .map(
                  (f) => DropdownMenuItem(
                    value: f,
                    child: Text(
                      f,
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _fontFamily = v ?? 'Arial'),
            underline: Container(),
            iconSize: 20,
            iconEnabledColor: const Color.fromARGB(255, 0, 0, 0),
            dropdownColor: const Color.fromARGB(255, 255, 254, 254), // <-- added
          ),

          DropdownButton<PaperSize>(
            value: _pageSize,
            items: const [
              DropdownMenuItem(
                value: PaperSize.a4,
                child: Text('A4', style: TextStyle(fontSize: 12, color: Colors.black)),
              ),
              DropdownMenuItem(
                value: PaperSize.short,
                child: Text('Short', style: TextStyle(fontSize: 12, color: Colors.black)),
              ),
              DropdownMenuItem(
                value: PaperSize.long,
                child: Text('Long', style: TextStyle(fontSize: 12, color: Colors.black)),
              ),
            ],
            onChanged: (v) => setState(() => _pageSize = v ?? PaperSize.a4),
            underline: Container(),
            iconSize: 20,
            iconEnabledColor: const Color.fromARGB(255, 0, 0, 0),
            dropdownColor: Colors.white, // <-- added
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _isHTMLView
              ? 'HTML Preview'
              : _isPrintView
                  ? 'Print View'
                  : 'Mobile View',
        ),
        actions: [
          
          IconButton(
            icon: Icon(_isPrintView ? Icons.smartphone : Icons.print),
            tooltip: _isPrintView ? 'Switch to Mobile View' : 'Switch to Print View',
            onPressed: _toggleView,
          ),
          IconButton(
            icon: Icon(_showFormattingToolbar ? Icons.keyboard_hide : Icons.format_size),
            tooltip: _showFormattingToolbar ? 'Hide Toolbar' : 'Show Toolbar',
            onPressed: _toggleFormattingToolbar,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Document',
            onPressed: _saveDocument,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFormattingToolbar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isHTMLView
                  ? SingleChildScrollView(
                      key: const ValueKey('html'),
                      padding: const EdgeInsets.all(16.0),
                      child: Html(
                        data: widget.initialText ?? "",
                        style: {
                          "p": Style(
                            margin: Margins.only(bottom: 8),
                            fontSize: FontSize(_fontSize),
                            fontFamily: _fontFamily,
                            color: Colors.black87,
                          ),
                          "span": Style(
                            fontSize: FontSize(_fontSize),
                            lineHeight: const LineHeight(1.5),
                          ),
                        },
                      ),
                    )
                  : (_isPrintView
                      ? PrintView(
                          key: ValueKey(_pageSize),
                          paginationManager: _paginationManager,
                          paperSize: _pageSize,
                          isBold: _isBold,
                          isItalic: _isItalic,
                          isUnderline: _isUnderline,
                          alignment: _alignment,
                          fontSize: _fontSize,
                          fontFamily: _fontFamily,
                        )
                      : MobileView(
                          key: ValueKey(_pageSize),
                          paginationManager: _paginationManager,
                          isBold: _isBold,
                          isItalic: _isItalic,
                          isUnderline: _isUnderline,
                          alignment: _alignment,
                          fontSize: _fontSize,
                          fontFamily: _fontFamily,
                        )),
            ),
          ),
        ],
      ),
    );
  }
}
