import 'package:flutter/material.dart';
import 'pagination_manager.dart';

class MobileView extends StatefulWidget {
  final PaginationManager paginationManager;

  // Formatting props
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final TextAlign alignment;
  final double fontSize;
  final String fontFamily;

  const MobileView({
    super.key,
    required this.paginationManager,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.alignment,
    required this.fontSize,
    required this.fontFamily,
  });

  @override
  State<MobileView> createState() => _MobileViewState();
}

class _MobileViewState extends State<MobileView> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.paginationManager.fullText);

    widget.paginationManager.addListener(() {
      if (_controller.text != widget.paginationManager.fullText) {
        _controller.text = widget.paginationManager.fullText;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      color: theme.scaffoldBackgroundColor,
      child: TextField(
        controller: _controller,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontSize: widget.fontSize,
          fontFamily: widget.fontFamily,
          fontWeight: widget.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: widget.isItalic ? FontStyle.italic : FontStyle.normal,
          decoration:
              widget.isUnderline ? TextDecoration.underline : TextDecoration.none,
          color: Colors.black87,
          height: 1.6,
        ),
        textAlign: widget.alignment,
        decoration: InputDecoration(
          hintText: 'Start typing here...',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black26),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black26),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
        onChanged: (value) => widget.paginationManager.updateContent(value),
      ),
    );
  }
}
