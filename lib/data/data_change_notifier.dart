import 'package:flutter/foundation.dart';

class DataChangeNotifier {
  DataChangeNotifier._();

  static final DataChangeNotifier instance = DataChangeNotifier._();

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  void notifyChanged() {
    version.value++;
  }
}
