import 'package:flutter/material.dart';

class CursorPosition {
  final int pageIndex;
  final int localPosition;

  const CursorPosition({
    required this.pageIndex,
    required this.localPosition,
  });
}

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

  StyledText copyWith({
    String? text,
    bool? bold,
    bool? italic,
    bool? underline,
    double? fontSize,
    String? fontFamily,
  }) {
    return StyledText(
      text ?? this.text,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

class PaginationManager extends ChangeNotifier {
  String _documentText = '';

  /// Linked container storage
  final List<List<StyledText>> _pages = [];

  /// Global cursor position (SINGLE SOURCE OF TRUTH)
  int _globalCursorPosition = 0;

  static const int _defaultCharsPerPage = 2500;

  PaginationManager();

  // ==============================
  // Getters
  // ==============================

  String get fullText => _documentText;
  List<List<StyledText>> get pages => List.unmodifiable(_pages);
  int get globalCursorPosition => _globalCursorPosition;

  // ==============================
  // Initialization
  // ==============================

  void initialize() {
    _documentText = '';
    _globalCursorPosition = 0;

    _pages
      ..clear()
      ..add([StyledText('')]);

    notifyListeners();
  }

  void loadInitialText(String text) {
    _documentText = text;
    _globalCursorPosition = 0;
    _paginateDefault();
    notifyListeners();
  }

  // ==============================
  // Mobile View Update
  // ==============================

  void updateContent(String newText) {
    _documentText = newText;
    _globalCursorPosition =
        _globalCursorPosition.clamp(0, _documentText.length);

    _paginateDefault();
    notifyListeners();
  }

  void setGlobalCursorPosition(int position) {
    _globalCursorPosition = position.clamp(0, _documentText.length);
    notifyListeners();
  }

  // ==============================
  // Print View Update (Linked Flow)
  // ==============================

  void updateFromPages(
    List<List<StyledText>> newPages, {
    required int editingPageIndex,
    required int localCursorOffset,
  }) {
    // Replace pages
    _pages
      ..clear()
      ..addAll(newPages);

    // Rebuild full document from pages
    _documentText = newPages
        .expand((page) => page)
        .map((e) => e.text)
        .join();

    // Convert local cursor → global cursor
    _globalCursorPosition =
        getGlobalFromLocal(editingPageIndex, localCursorOffset);

    notifyListeners();
  }

  // ==============================
  // Global ↔ Local Cursor Mapping
  // ==============================

  CursorPosition getLocalCursorFromGlobal() {
    int current = 0;

    for (int i = 0; i < _pages.length; i++) {
      final pageText = _pages[i].map((e) => e.text).join();
      final length = pageText.length;

      if (_globalCursorPosition <= current + length) {
        return CursorPosition(
          pageIndex: i,
          localPosition: _globalCursorPosition - current,
        );
      }

      current += length;
    }

    // Fallback to last page
    return CursorPosition(
      pageIndex: _pages.isEmpty ? 0 : _pages.length - 1,
      localPosition: _pages.isEmpty
          ? 0
          : _pages.last.map((e) => e.text).join().length,
    );
  }

  int getGlobalFromLocal(int pageIndex, int localOffset) {
    if (_pages.isEmpty) return 0;

    int global = 0;

    for (int i = 0; i < pageIndex && i < _pages.length; i++) {
      global += _pages[i].map((e) => e.text).join().length;
    }

    return (global + localOffset).clamp(0, _documentText.length);
  }

  // ==============================
  // Basic Pagination (Mobile Mode)
  // ==============================

  void _paginateDefault() {
    _pages.clear();

    if (_documentText.isEmpty) {
      _pages.add([StyledText('')]);
      return;
    }

    for (int i = 0; i < _documentText.length; i += _defaultCharsPerPage) {
      final end = (i + _defaultCharsPerPage > _documentText.length)
          ? _documentText.length
          : i + _defaultCharsPerPage;

      _pages.add([
        StyledText(_documentText.substring(i, end)),
      ]);
    }

    if (_pages.isEmpty) {
      _pages.add([StyledText('')]);
    }
  }
}
