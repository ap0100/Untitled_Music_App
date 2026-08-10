import 'package:flutter/material.dart';
import 'package:palette_generator_master/palette_generator_master.dart';

class ColorUtils {
  static final Map<String, Color> _colorCache = {};

  static Color? getCachedColor(String imageUrl) {
    return _colorCache[imageUrl];
  }

  static Future<Color?> getPrimaryColor(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    // Check cache first
    if (_colorCache.containsKey(imageUrl)) {
      return _colorCache[imageUrl];
    }

    try {
      final generator = await PaletteGeneratorMaster.fromImageProvider(
        NetworkImage(imageUrl),
      );
      final color =
          generator.dominantColor?.color ?? Color.fromARGB(255, 37, 23, 37);
      _colorCache[imageUrl] = color;
      return color;
    } catch (e) {
      return null;
    }
  }

  /*static double getBrightness(Color? color) {
    // Calculate perceived brightness (0-1)
    return (0.299 * color!.r + 0.587 * color.g + 0.114 * color.b) / 255;
  }
*/
  Color? darken(Color? color, double opacity) {
    if (color == null) return null;
    return Color.alphaBlend(
      const Color.fromARGB(255, 34, 24, 36).withValues(alpha: opacity),
      color,
    );
  }
}
