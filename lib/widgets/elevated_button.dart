import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class MyElevatedButton extends StatelessWidget {
  final String buttonText;
  final Color bgClr;
  final Color borderClr;
  final Color textClr;
  final bool isLoading;
  final VoidCallback onPressed;
  final double height;
  final double width;
  final double radius;
  final double fontSize;

  const MyElevatedButton({
    super.key,
    required this.buttonText,
    required this.onPressed,
    this.bgClr = blueColor,
    this.borderClr = mobileBackgroundColor,
    this.textClr = primaryColor,
    this.isLoading = false,
    this.height = 50,
    this.width = double.infinity,
    this.radius = 20,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgClr,
        minimumSize: Size(width, height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child:
          isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 2,
                ),
              )
              : Text(
                buttonText,
                style: TextStyle(color: textClr, fontSize: fontSize),
              ),
    );
  }
}
