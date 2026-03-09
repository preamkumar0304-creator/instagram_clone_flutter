import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class TextFieldInput extends StatelessWidget {
  final TextEditingController textEditingController;
  final bool isPass;
  final String labelText;
  final TextInputType textInputType;
  const TextFieldInput({
    super.key,
    required this.labelText,
    this.isPass = false,
    required this.textEditingController,
    required this.textInputType,
  });

  @override
  Widget build(BuildContext context) {
    final eBorder = OutlineInputBorder(
      borderSide: BorderSide(color: secondaryColor, width: 1.5),
      borderRadius: BorderRadius.circular(12),
    );
    final fBorder = OutlineInputBorder(
      borderSide: BorderSide(color: primaryColor, width: 1.5),
      borderRadius: BorderRadius.circular(12),
    );
    return TextField(
      controller: textEditingController,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: primaryColor,fontSize:16,),
        enabledBorder: eBorder,
        focusedBorder: fBorder,
        filled: true,
        fillColor: mobileBackgroundColor,
      ),
      keyboardType: textInputType,
      obscureText: isPass,
    );
  }
}
