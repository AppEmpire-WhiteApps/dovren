import 'package:flutter/material.dart';

/// Owns the progress and page motion for Dovren's quiet-reading introduction.
class QuietStartGuide extends ChangeNotifier {
  QuietStartGuide({required this.pageCount});

  final int pageCount;
  final PageController pages = PageController();
  int _currentPage = 0;

  int get currentPage => _currentPage;
  bool get isLastPage => _currentPage == pageCount - 1;

  void recordVisiblePage(int page) {
    if (page == _currentPage) return;
    _currentPage = page;
    notifyListeners();
  }

  Future<void> advance() => pages.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }
}
