import 'package:flutter/material.dart';

class PhantomTextField extends StatelessWidget {
  const PhantomTextField({
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.autofillHints,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      autofillHints: autofillHints,
      decoration: InputDecoration(labelText: label),
    );
  }
}
