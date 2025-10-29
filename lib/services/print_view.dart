import 'package:flutter/material.dart';
import 'pagination_manager.dart';

enum PaperSize { a4, short, long }

class PrintView extends StatefulWidget {
  final PaginationManager paginationManager;
  final PaperSize paperSize;

  // Formatting props
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final TextAlign alignment;
  final double fontSize;
  final String fontFamily;

  const PrintView({
    super.key,
    required this.paginationManager,
    this.paperSize = PaperSize.a4,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.alignment,
    required this.fontSize,
    required this.fontFamily,
  });

  @override
  State<PrintView> createState() => _PrintViewState();
}

class _PrintViewState extends State<PrintView> {
  final double _fixedZoom = 0.9;
  late Map<PaperSize, Size> _paperDimensions;
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _paperDimensions = {
      PaperSize.a4: const Size(794, 1123),
      PaperSize.short: const Size(816, 1056),
      PaperSize.long: const Size(816, 1248),
    };

    _initControllers();
    widget.paginationManager.addListener(_syncControllers);
  }

  void _initControllers() {
    for (final page in widget.paginationManager.pages) {
      // Convert List<StyledText> to plain text
      final plainText = page.map((s) => s.text).join('\n');
      _controllers.add(TextEditingController(text: plainText));
      _focusNodes.add(FocusNode());
    }
  }

  void _syncControllers() {
    final newPages = widget.paginationManager.pages;

    while (_controllers.length < newPages.length) {
      _controllers.add(TextEditingController(text: ''));
      _focusNodes.add(FocusNode());
    }

    while (_controllers.length > newPages.length) {
      _controllers.removeLast().dispose();
      _focusNodes.removeLast().dispose();
    }

    for (int i = 0; i < newPages.length; i++) {
      final plainText = newPages[i].map((s) => s.text).join('\n');
      if (_controllers[i].text != plainText) {
        _controllers[i].text = plainText;
      }
    }

    setState(() {});

    // Optional: remove last empty controller if more than 1 page
    if (_controllers.length > 1 && _controllers.last.text.trim().isEmpty) {
      _controllers.removeLast();
      _focusNodes.removeLast();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    widget.paginationManager.removeListener(_syncControllers);
    super.dispose();
  }

  void _onTextChanged(int index) {
    // Convert each controller's text to List<StyledText>
    final updatedPages = _controllers
        .map((c) => [StyledText(c.text)])
        .toList();

    final cursorPos = _controllers[index].selection.baseOffset;

    widget.paginationManager.updateFromPages(
      updatedPages,
      editingPageIndex: index,
      cursorPosition: cursorPos,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paper = _paperDimensions[widget.paperSize]!;
    final zoom = _fixedZoom;

    return Container(
      color: const Color(0xFFD6D6D6),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24),
        itemCount: _controllers.length,
        itemBuilder: (context, index) {
          final controller = _controllers[index];
          final focusNode = _focusNodes[index];

          return Center(
            child: Transform.scale(
              scale: zoom,
              alignment: Alignment.topCenter,
              child: Container(
                width: paper.width,
                height: paper.height,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300, width: 1.0),
                  borderRadius: BorderRadius.circular(4.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: null,
                    onChanged: (_) => _onTextChanged(index),
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontFamily: widget.fontFamily,
                      fontWeight: widget.isBold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: widget.isItalic ? FontStyle.italic : FontStyle.normal,
                      decoration: widget.isUnderline
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                    textAlign: widget.alignment,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    keyboardType: TextInputType.multiline,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
