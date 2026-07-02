import 'package:flutter/material.dart';

String moneyText(double value) => value.toStringAsFixed(2);

String dateText(DateTime value) {
  return '${value.year}-${_two(value.month)}-${_two(value.day)}';
}

String dateTimeText(DateTime value) {
  return '${dateText(value)} ${_two(value.hour)}:${_two(value.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

DateTime dayStart(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime dayEnd(DateTime value) {
  return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = '确认',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}
