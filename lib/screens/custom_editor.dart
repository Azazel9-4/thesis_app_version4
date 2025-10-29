import 'package:flutter/material.dart';

class CustomEditorScreen extends StatefulWidget {
  const CustomEditorScreen({super.key});

  @override
  State<CustomEditorScreen> createState() => _CustomEditorScreenState();
}

class _CustomEditorScreenState extends State<CustomEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Formatting state
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  TextAlign _alignment = TextAlign.left;
  double _fontSize = 14;
  String _fontFamily = 'Arial';

  // Stores the formatted text spans
  List<InlineSpan> _spans = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateSpans);
    _spans = [TextSpan(text: '', style: _getTextStyle())];
  }

  TextStyle _getTextStyle({bool? bold, bool? italic, bool? underline, double? size, String? font}) {
    return TextStyle(
      fontWeight: (bold ?? _isBold) ? FontWeight.bold : FontWeight.normal,
      fontStyle: (italic ?? _isItalic) ? FontStyle.italic : FontStyle.normal,
      decoration: (underline ?? _isUnderline) ? TextDecoration.underline : TextDecoration.none,
      fontSize: size ?? _fontSize,
      fontFamily: font ?? _fontFamily,
      color: Colors.white,
    );
  }

  void _updateSpans() {
    final text = _controller.text;
    if (text.isEmpty) {
      _spans = [TextSpan(text: '', style: _getTextStyle())];
    } else if (_controller.selection.isCollapsed) {
      // No selection, keep existing style
    } else {
      final start = _controller.selection.start;
      final end = _controller.selection.end;

      final before = text.substring(0, start);
      final selected = text.substring(start, end);
      final after = text.substring(end);

      _spans = [
        if (before.isNotEmpty) TextSpan(text: before, style: _getTextStyle()),
        if (selected.isNotEmpty) TextSpan(text: selected, style: _getTextStyle()),
        if (after.isNotEmpty) TextSpan(text: after, style: _getTextStyle()),
      ];
    }
    setState(() {});
  }

  void _applyFormatting(void Function() toggleFormat) {
    final selection = _controller.selection;
    if (!selection.isCollapsed) {
      toggleFormat();
      _updateSpans();
    } else {
      // If no selection, toggle future typing style
      toggleFormat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E2C),
      appBar: AppBar(
        title: const Text('Custom Editor'),
        backgroundColor: const Color(0xFF121430),
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            color: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isBold ? Icons.format_bold : Icons.format_bold_outlined, color: Colors.white),
                    onPressed: () => _applyFormatting(() => _isBold = !_isBold),
                  ),
                  IconButton(
                    icon: Icon(_isItalic ? Icons.format_italic : Icons.format_italic_outlined, color: Colors.white),
                    onPressed: () => _applyFormatting(() => _isItalic = !_isItalic),
                  ),
                  IconButton(
                    icon: Icon(_isUnderline ? Icons.format_underline : Icons.format_underline_outlined, color: Colors.white),
                    onPressed: () => _applyFormatting(() => _isUnderline = !_isUnderline),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<TextAlign>(
                    value: _alignment,
                    dropdownColor: Colors.grey.shade800,
                    items: const [
                      DropdownMenuItem(value: TextAlign.left, child: Text('Left', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: TextAlign.center, child: Text('Center', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: TextAlign.right, child: Text('Right', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: TextAlign.justify, child: Text('Justify', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (v) => setState(() => _alignment = v ?? TextAlign.left),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<double>(
                    value: _fontSize,
                    dropdownColor: Colors.grey.shade800,
                    items: [12, 14, 16, 18, 20, 24, 28, 32]
                        .map((f) => DropdownMenuItem(value: f.toDouble(), child: Text('$f', style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (v) => setState(() => _fontSize = v ?? 14),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _fontFamily,
                    dropdownColor: Colors.grey.shade800,
                    items: ['Arial', 'Times New Roman', 'Calibri', 'Courier New']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (v) => setState(() => _fontFamily = v ?? 'Arial'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Editor
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0B0E2C),
              child: SingleChildScrollView(
                child: RichText(
                  textAlign: _alignment,
                  text: TextSpan(children: _spans),
                ),
              ),
            ),
          ),

          // Hidden TextField for input
          SizedBox(
            height: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              style: const TextStyle(color: Colors.transparent),
              cursorColor: Colors.white,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }
}
