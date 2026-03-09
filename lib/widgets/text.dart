import 'package:flutter/material.dart';

class MyText extends StatelessWidget {
  final String text;
  final Color textClr;
  final double textSize;
  final FontWeight textWeight;
  const MyText({
    super.key,
    required this.text,
    required this.textClr,
    required this.textSize,
    this.textWeight=FontWeight.normal
  });

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: textClr, fontSize: textSize,fontWeight: textWeight));
  }
}
