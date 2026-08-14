import 'package:flutter/material.dart';

class JinxTheme {
  static const Color deepCerise = Color.fromARGB(169, 253, 62, 253);
  static const Color brightTurquoise = Color.fromARGB(148, 34, 239, 242);
  static const Color tyrianPurple = Color.fromARGB(255, 131, 7, 110);
  static const Color regalBlue = Color.fromRGBO(30, 57, 87, 1);
  static const Color darkWarm = Color.fromARGB(255, 36, 8, 16);
  static const Color darkCold = Color.fromARGB(255, 8, 36, 32);
  static const Color violetBlue = Color.fromARGB(255, 235, 97, 205);
  static const Color midnightExpress = Color(0xFF0E1C3F);
}

class MiniPlayerClipper extends CustomClipper<Path> {
  final double offset;
  final bool cover;

  MiniPlayerClipper({this.offset = 0, this.cover = false});

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    if (cover) {
      path.lineTo(0, h);
      path.lineTo(0, (h - 45));
      path.lineTo(15, (h - 53));
      path.lineTo(w + offset, (h - 60));
      path.lineTo((w - 10) + offset, h - 50);
      path.lineTo((w - 15) + offset, h - 40);
      path.lineTo((w - 10) + offset, h - 30);
      path.lineTo((w - 12) + offset, h - 10);
      path.lineTo((w - 5) + offset, h);
      path.lineTo(0, h);
      path.close();

      return path;
    }

    path.lineTo(0, h);
    path.lineTo(0, (h - 45) - offset);
    path.lineTo(15, (h - 55) - offset);
    path.lineTo(100, (h - 53) - offset);
    path.lineTo(110, (h - 60) - offset);
    path.lineTo(w - 15, (h - 60) - offset);
    path.lineTo(w, (h - 53) - offset);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
