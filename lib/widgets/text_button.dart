import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class MyTextButton extends StatelessWidget {
  final String buttonText;
  final Color txtClr;
  final VoidCallback onPressed;

  const MyTextButton({
    super.key,
    required this.buttonText,
    this.txtClr = primaryColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(),
      child: Text(buttonText, style: TextStyle(color: txtClr, fontSize: 16)),
    );
  }
}
