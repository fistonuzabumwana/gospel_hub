import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Curl state for the paper page-turn shader.
class PaperCurlController extends ChangeNotifier {
  PaperCurlController({this.radius = 0.07});

  final double radius;

  bool _isCurling = false;
  bool _isReverse = false;
  double _curlProgress = 0;
  Offset _curlPosition = Offset.zero;
  Offset _curlDirection = const Offset(1, 0);
  Offset _startPosition = Offset.zero;

  bool get isCurling => _isCurling;
  bool get isReverse => _isReverse;
  double get curlProgress => _curlProgress;
  Offset get curlPosition => _curlPosition;
  Offset get curlDirection => _curlDirection;
  Offset get startPosition => _startPosition;

  void startCurl(Offset startPos, {bool reverse = false}) {
    _isCurling = true;
    _isReverse = reverse;
    _startPosition = startPos;
    _curlPosition = startPos;
    _curlDirection = reverse ? const Offset(-1, 0) : const Offset(1, 0);
    _curlProgress = 0;
    notifyListeners();
  }

  void updateCurl(Offset currentPos) {
    if (!_isCurling) return;

    // Soft limit on diagonal so a corner peel can't free the left spine
    // (top near TT / bottom near Home). Does NOT lock the whole top/bottom.
    var delta = _startPosition - currentPos;
    final maxDy = math.max(delta.dx.abs() * 0.45, 0.001);
    delta = Offset(delta.dx, delta.dy.clamp(-maxDy, maxDy));

    // Live drag cannot pass the left spine — page stays stapled there.
    // Final settle may still peel off-screen when the turn commits.
    var pinnedX = currentPos.dx < 0.0 ? 0.0 : currentPos.dx;
    // Also never pass the flat start on the right (avoids direction flip).
    if (pinnedX > _startPosition.dx) {
      pinnedX = _startPosition.dx;
    }
    _curlPosition = Offset(pinnedX, currentPos.dy);

    final length = delta.distance;
    if (length > 0.001 && delta.dx > 0.001) {
      _curlDirection = Offset(delta.dx / length, delta.dy / length);
    }

    if (_isReverse) {
      _curlProgress = (pinnedX - _startPosition.dx).clamp(0.0, 1.0);
    } else {
      _curlProgress = (_startPosition.dx - pinnedX).clamp(0.0, 1.0);
    }

    notifyListeners();
  }

  /// Settle animation may move past the spine (e.g. peel off on commit).
  /// When [freezeDirection] is true, direction is not recalculated — used for
  /// rewind flatten so we never flip into an upside fold at the end.
  void updateCurlUnclamped(
    Offset currentPos, {
    bool freezeDirection = false,
  }) {
    if (!_isCurling) return;
    _curlPosition = currentPos;

    final delta = _startPosition - currentPos;
    final length = delta.distance;
    if (!freezeDirection && length > 0.001) {
      // Crossing past the flat start flips delta.dx and inverts the fold.
      // Keep the previous direction once we're at/flat past the start.
      if (delta.dx > 0.001) {
        _curlDirection = Offset(delta.dx / length, delta.dy / length);
      }
    }

    if (_isReverse) {
      _curlProgress = (currentPos.dx - _startPosition.dx).clamp(0.0, 1.0);
    } else {
      _curlProgress = (_startPosition.dx - currentPos.dx).clamp(0.0, 1.0);
    }

    notifyListeners();
  }

  void cancelCurl() {
    _isCurling = false;
    _curlProgress = 0;
    notifyListeners();
  }
}
