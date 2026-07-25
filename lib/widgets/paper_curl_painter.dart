import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'paper_curl_controller.dart';

/// Renders the cylinder page-curl GLSL effect (real paper peel).
class PaperCurlPainter extends CustomPainter {
  PaperCurlPainter({
    required this.shader,
    required this.controller,
    required this.currentPageImage,
    required this.nextPageImage,
    required this.paperColor,
    this.shadowWidth = 0.15,
  }) : super(repaint: controller);

  final ui.FragmentShader shader;
  final PaperCurlController controller;
  final ui.Image currentPageImage;
  final ui.Image nextPageImage;
  final Color paperColor;
  final double shadowWidth;

  @override
  void paint(Canvas canvas, Size size) {
    var idx = 0;
    shader.setFloat(idx++, size.width);
    shader.setFloat(idx++, size.height);
    shader.setFloat(idx++, controller.curlPosition.dx);
    shader.setFloat(idx++, controller.curlPosition.dy);
    shader.setFloat(idx++, controller.curlDirection.dx);
    shader.setFloat(idx++, controller.curlDirection.dy);
    shader.setFloat(idx++, controller.radius);
    shader.setFloat(idx++, shadowWidth);
    shader.setFloat(idx++, paperColor.r);
    shader.setFloat(idx++, paperColor.g);
    shader.setFloat(idx++, paperColor.b);
    shader.setFloat(idx++, controller.isReverse ? 1.0 : 0.0);
    shader.setImageSampler(0, currentPageImage);
    shader.setImageSampler(1, nextPageImage);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant PaperCurlPainter oldDelegate) {
    return oldDelegate.currentPageImage != currentPageImage ||
        oldDelegate.nextPageImage != nextPageImage ||
        oldDelegate.controller != controller ||
        oldDelegate.shadowWidth != shadowWidth ||
        oldDelegate.paperColor != paperColor;
  }
}
