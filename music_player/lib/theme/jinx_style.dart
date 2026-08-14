import 'package:flutter/material.dart';

class JinxTheme {
  static const Color deepCerise = Color(0xFFFD3EFD);
  static const Color brightTurquoise = Color(0xFF22EFF2);
  static const Color tyrianPurple = Color.fromARGB(255, 85, 5, 72);
  static const Color regalBlue = Color.fromRGBO(30, 57, 87, 1);
  static const Color darkWarm = Color.fromARGB(255, 36, 8, 16);
  static const Color darkCold = Color.fromARGB(255, 8, 36, 32);
  static const Color violetBlue = Color(0xFFB0569D);
  static const Color midnightExpress = Color(0xFF0E1C3F);
}

class BeveledClipper extends CustomClipper<Path> {
  final double bevelSize;

  BeveledClipper({this.bevelSize = 10});

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final b = bevelSize;

    path.moveTo(b, 0);
    path.lineTo(w - b, 0);
    path.lineTo(w, b);
    path.lineTo(w, h - b);
    path.lineTo(w - b, h);
    path.lineTo(b, h);
    path.lineTo(0, h - b);
    path.lineTo(0, b);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class BeveledContainer extends StatelessWidget {
  final Widget child;
  final double bevelSize;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets padding;

  const BeveledContainer({
    required this.child,
    this.bevelSize = 12.0,
    this.color = JinxTheme.regalBlue,
    this.borderColor,
    this.borderWidth = 1.5,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: BeveledClipper(bevelSize: bevelSize),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: borderWidth)
              : null,
        ),
        child: child,
      ),
    );
  }
}
