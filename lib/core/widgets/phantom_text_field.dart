import 'package:flutter/material.dart';

class PhantomTextField extends StatefulWidget {
  const PhantomTextField({
    required this.label,
    this.controller,
    this.obscureText = false,
    this.canToggleObscureText = false,
    this.keyboardType,
    this.validator,
    this.autofillHints,
    this.onChanged,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;

  /// Adds a visibility-toggle suffix icon when [obscureText] is true — used
  /// by password fields (e.g. Create Account) where showing/hiding the
  /// typed value helps the user confirm it before submitting.
  final bool canToggleObscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  @override
  State<PhantomTextField> createState() => _PhantomTextFieldState();
}

class _PhantomTextFieldState extends State<PhantomTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: widget.canToggleObscureText
            ? IconButton(
                icon: Icon(_obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                tooltip: _obscured ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
      ),
    );
  }
}
