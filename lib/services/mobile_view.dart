import 'package:flutter/material.dart';
import 'pagination_manager.dart';

class MobileView extends StatefulWidget {
  final PaginationManager paginationManager;
  final bool isBold, isItalic, isUnderline;
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
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
        text: widget.paginationManager.fullText);

    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreCursor();
    });

    widget.paginationManager.addListener(() {
      if (_controller.text !=
          widget.paginationManager.fullText) {
        final previous =
            widget.paginationManager.globalCursorPosition;

        _controller.text =
            widget.paginationManager.fullText;

        _controller.selection =
            TextSelection.collapsed(
                offset: previous.clamp(
                    0, _controller.text.length));
      }
    });
  }

  void _restoreCursor() {
    final pos =
        widget.paginationManager.globalCursorPosition;

    _focusNode.requestFocus();

    _controller.selection = TextSelection.collapsed(
        offset: pos.clamp(0, _controller.text.length));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        expands: true,
        onChanged: (value) {
          widget.paginationManager.updateContent(value);

          widget.paginationManager.setGlobalCursorPosition(
              _controller.selection.baseOffset);
        },
        style: TextStyle(
          fontSize: widget.fontSize,
          fontFamily: widget.fontFamily,
          fontWeight: widget.isBold
              ? FontWeight.bold
              : FontWeight.normal,
          fontStyle: widget.isItalic
              ? FontStyle.italic
              : FontStyle.normal,
          decoration: widget.isUnderline
              ? TextDecoration.underline
              : TextDecoration.none,
          height: 1.5,
          color: Colors.black,
        ),
        textAlign: widget.alignment,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.fromLTRB(20, 20, 20, 40),
        ),
      ),
    );
  }
}
