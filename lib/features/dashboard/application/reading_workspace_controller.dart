import 'package:flutter/foundation.dart';

/// Coordinates the four work areas used while configuring recipe protection.
class ReadingWorkspaceController extends ChangeNotifier {
  int _selectedArea = 0;

  int get selectedArea => _selectedArea;

  void showShield() => selectArea(0);

  void showRuleBook() => selectArea(1);

  void showReadingInsights() => selectArea(2);

  void showPreferences() => selectArea(3);

  void selectArea(int area) {
    if (area == _selectedArea) return;
    _selectedArea = area;
    notifyListeners();
  }
}
