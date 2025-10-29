import 'package:flutter/material.dart';

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

class PaginationManager extends ChangeNotifier {
  String _documentText = '';
  final List<List<StyledText>> _pages = []; // changed to store StyledText per page

  String get fullText => _documentText;

  static const int _defaultCharsPerPage = 2500;
  static const int _pageBuffer = 50; // tolerance before forcing new page

  PaginationManager();

  void initialize() {
    _documentText = '';
    _pages
      ..clear()
      ..add([StyledText('')]); // empty StyledText
    notifyListeners();
  }

  void loadInitialText(String text) {
    _documentText = text;
    _paginateDefault();
    notifyListeners();
  }

  /// 🔹 Used by mobile view — updates entire document at once
  void updateContent(String newText) {
    _documentText = newText;
    _paginateDefault();
    notifyListeners();
  }

  List<List<StyledText>> get pages => List.unmodifiable(_pages);

  /// 🔹 Used by PrintView — dynamically handles typing/backspace like MS Word
  void updateFromPages(
    List<List<StyledText>> newPages, {
    int? editingPageIndex,
    int? cursorPosition,
  }) {
    // Merge all text into one continuous document
    _documentText = newPages
        .expand((page) => page)
        .map((e) => e.text)
        .join('\n\n');

    // Recalculate pages so that text flows between them
    _reflowPages();

    notifyListeners();
  }

  /// 🔹 Used for initial pagination or when new text is loaded
  void _paginateDefault() {
    _pages.clear();

    if (_documentText.isEmpty) {
      _pages.add([StyledText('')]);
      return;
    }

    final text = _documentText;
    for (int i = 0; i < text.length; i += _defaultCharsPerPage) {
      final end = (i + _defaultCharsPerPage > text.length)
          ? text.length
          : i + _defaultCharsPerPage;

      _pages.add([StyledText(text.substring(i, end).trim())]);
    }

    if (_pages.isEmpty) _pages.add([StyledText('')]);
  }

  /// 🔹 Smart reflow: Keeps text moving across pages like in Word
  void _reflowPages() {
    _pages.clear();

    if (_documentText.isEmpty) {
      _pages.add([StyledText('')]);
      return;
    }

    final text = _documentText;
    final buffer = StringBuffer();
    int count = 0;

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      count++;

      // When we hit the page limit, break into a new page
      if (count >= _defaultCharsPerPage && i < text.length - 1) {
        _pages.add([StyledText(buffer.toString().trim())]);
        buffer.clear();
        count = 0;
      }
    }

    // Add last partial page
    if (buffer.isNotEmpty) _pages.add([StyledText(buffer.toString().trim())]);

    // Clean up any empty tail pages
    _cleanupEmptyPages();

    // Always keep one empty page at end for continuous typing
    if (_pages.isEmpty ||
        _pages.last.first.text.length > _defaultCharsPerPage - _pageBuffer) {
      _pages.add([StyledText('')]);
    }
  }

  void _cleanupEmptyPages() {
    while (_pages.length > 1 && _pages.last.first.text.trim().isEmpty) {
      _pages.removeLast();
    }
  }
}
