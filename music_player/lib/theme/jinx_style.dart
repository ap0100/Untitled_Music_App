import 'package:flutter/material.dart';

class JinxTheme {
  static const Color deepCerise = Color.fromARGB(169, 253, 62, 253);
  static const Color brightTurquoise = Color.fromARGB(148, 34, 239, 242);
  static const Color tyrianPurple = Color.fromARGB(255, 131, 7, 110);
  static const Color regalBlue = Color.fromRGBO(53, 100, 153, 1);
  static const Color darkWarm = Color.fromARGB(255, 36, 8, 16);
  static const Color darkCold = Color.fromARGB(255, 8, 36, 32);
  static const Color violetBlue = Color.fromARGB(255, 235, 97, 205);
  static const Color midnightExpress = Color.fromARGB(255, 11, 23, 51);
  static const Color dark = Color.fromARGB(255, 24, 8, 39);
  static const Color midnightExpressOpposite = Color.fromARGB(255, 36, 8, 32);
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
      path.lineTo(15, (h - 55));
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
    path.lineTo(100, (h - 55) - offset);
    path.lineTo(110, (h - 55) - offset);
    path.lineTo(w - 15, (h - 55) - offset);
    path.lineTo(w, (h - 50) - offset);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class TrackDisplayClipper extends CustomClipper<Path> {
  final double offset;
  final bool cover;

  TrackDisplayClipper({this.offset = 0, this.cover = false});

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    if (cover) {
      path.lineTo(0, h - 40);
      path.lineTo(15 + offset, h - 80);
      path.lineTo(w + offset, h - 60);
      path.lineTo(w - 20 + offset, h);
      path.lineTo(0, h);
      path.close();

      return path;
    }

    // 1. Start at (0,0), go straight down the left edge to start the bevel
    path.lineTo(offset == 0 ? 2 : 0, (h - 35) - offset);
    // 2. Draw the top-left bevel (matches the thumbnail)
    path.lineTo(offset == 0 ? 15 : 10 - offset, (h - 60) - offset);
    // 3. Draw the top edge across to the right
    path.lineTo(w, (h - 60) - offset);
    // 4. Right edge (preserving your original offset logic, traced top-to-bottom)
    path.lineTo(w, offset == 0 ? 0 : h - 10);
    path.lineTo(offset == 0 ? w - 8 : w, 0);
    path.lineTo(offset == 0 ? w - 2 : w, (h - 10));
    path.lineTo(w - 15, (offset == 0 ? h : h + 8));
    // 5. Bottom edge (go to bottom-left)
    path.lineTo(offset == 0 ? 15 : 10, h);
    // 6. Left edge (straight up to close the shape at the start of the bevel)
    path.lineTo(offset == 0 ? 2 : 0, h - 35);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
