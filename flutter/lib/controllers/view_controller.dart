import 'package:flutter/material.dart';

class ViewController extends ChangeNotifier {
  bool isMap = false;

  void toggle() {
    isMap = !isMap;
    notifyListeners();
  }
}

final viewController = ViewController();