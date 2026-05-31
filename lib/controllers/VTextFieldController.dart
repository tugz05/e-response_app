import 'package:flutter/material.dart';

class VTextFieldController {
  final TextEditingController textController = TextEditingController();
  bool obscureText = true;

  // Convenience getter for the text property
  String get text => textController.text;

  // Convenience setter for the text property
  set text(String value) => textController.text = value;

  // Toggle visibility for password field
  void toggleObscureText() {
    obscureText = !obscureText;
  }

  // Dispose controller when no longer needed
  void dispose() {
    textController.dispose();
  }
}
