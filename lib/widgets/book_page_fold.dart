import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'paper_curl_controller.dart';
import 'paper_curl_painter.dart';

/// Direction of a completed book page turn.
enum BookPageTurnDirection { forward, backward }

/// Real paper page-curl: cylinder peel that follows the finger.
///
/// [loadDestinationPage] should return the next/previous chapter UI so it can
/// be snapped and revealed gradually under the turning page.
class BookPageFold extends StatefulWidget {
  final Widget child;
  final bool canTurnForward;
  final bool canTurnBackward;
  final Future<void> Function(BookPageTurnDirection direction) onTurn;
  final Future<Widget?> Function(BookPageTurnDirection direction) loadDestinationPage;
  final Color paperColor;
  final Color shadowColor;

  const BookPageFold({
    super.key,
    required this.child,
    required this.canTurnForward,
    required this.canTurnBackward,
    required this.onTurn,
    required this.loadDestinationPage,
    required this.paperColor,
    this.shadowColor = const Color(0x99000000),
  });

  @override
  State<BookPageFold> createState() => _BookPageFoldState();
}

class _BookPageFoldState extends State<BookPageFold>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _destinationKey = GlobalKey();
  final PaperCurlController _curl = PaperCurlController(radius: 0.08);

  ui.FragmentShader? _shader;
  bool _shaderReady = false;
  bool _shaderFailed = false;

  ui.Image? _currentImage;
  ui.Image? _underImage;
  Widget? _destinationPreview;
  Size? _captureSize;

  late final AnimationController _settleController;
  Offset _settleFrom = Offset.zero;
  Offset _settleTo = Offset.zero;
  bool _settleIsCommit = false;
  bool _settleFinishing = false;

  bool _axisLockedHorizontal = false;
  bool _axisLockedVertical = false;
  bool _isTurning = false;
  bool _isCapturing = false;
  /// Previous-chapter turn: same fold geometry as forward, played backwards.
  bool _isRewind = false;
  int? _activePointer;
  Offset? _pointerStartLocal;
  Offset? _lastPointerLocal;
  DateTime? _lastMoveTime;
  double _velocityX = 0;
  BookPageTurnDirection? _turnDirection;

  static const double _axisLockSlop = 10;
  static const double _commitProgress = 0.18;
  static const double _commitVelocityPxPerMs = 0.30;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )
      ..addListener(_onSettleTick)
      ..addStatusListener(_onSettleStatus);
    _loadShader();
  }

  @override
  void dispose() {
    _settleController.dispose();
    _disposeImages(immediate: true);
    _shader?.dispose();
    _curl.dispose();
    super.dispose();
  }

  /// Drop texture refs. Defer GPU dispose one frame so Impeller isn't still
  /// sampling them (native crash on many Android devices).
  void _disposeImages({bool immediate = false}) {
    final current = _currentImage;
    final under = _underImage;
    _currentImage = null;
    _underImage = null;
    if (immediate) {
      current?.dispose();
      under?.dispose();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      current?.dispose();
      under?.dispose();
    });
  }

  void _replaceCurrentImage(ui.Image next) {
    final old = _currentImage;
    _currentImage = next;
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  void _replaceUnderImage(ui.Image next) {
    final old = _underImage;
    _underImage = next;
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/page_curl.frag');
      if (!mounted) return;
      setState(() {
        _shader = program.fragmentShader();
        _shaderReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _shaderFailed = true);
    }
  }

  Size get _widgetSize {
    final box = context.findRenderObject() as RenderBox?;
    return box?.hasSize == true ? box!.size : Size.zero;
  }

  Offset _normalize(Offset local) {
    final size = _widgetSize;
    if (size.width <= 0 || size.height <= 0) return Offset.zero;
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  /// Finger → curl control point.
  ///
  /// Forward: finger peels the page away.
  /// Rewind (previous): same fold path played backwards — starts at the left
  /// spine (stapled near TT) and lays the previous page back down as you
  /// swipe right. Drag never passes the left spine; only commit settle may.
  Offset _curlDrivePos(Offset localPos) {
    final finger = _normalize(localPos);
    final y = finger.dy.clamp(0.12, 0.88);

    if (_isRewind) {
      final gestureStart = _normalize(_pointerStartLocal ?? localPos);
      // 0 at swipe start → at left spine; 1 after right swipe → flat (at start).
      // Cap at 1.0 — going past start flips curl direction (upside fold flash).
      final t = ((finger.dx - gestureStart.dx) / 0.9).clamp(0.0, 1.0);
      final x = ui.lerpDouble(0.0, 1.0, t)!;
      return Offset(x, y);
    }
    // Live drag stops at the stapled left edge (x == 0).
    return Offset(finger.dx.clamp(0.0, 1.0), y);
  }

  Future<ui.Image?> _captureBoundary(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return null;
    try {
      final ratio = MediaQuery.devicePixelRatioOf(ctx).clamp(1.0, 2.0);
      return await boundary.toImage(pixelRatio: ratio);
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _flattenOpaque(ui.Image src) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble());
    canvas.drawRect(
      rect,
      Paint()
        ..color = widget.paperColor.withValues(alpha: 1.0)
        ..style = PaintingStyle.fill,
    );
    canvas.drawImage(src, Offset.zero, Paint());
    final picture = recorder.endRecording();
    final flat = await picture.toImage(src.width, src.height);
    src.dispose();
    return flat;
  }

  Future<ui.Image> _paperTexture(Size logicalSize) async {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final w = math.max(1, (logicalSize.width * dpr).round());
    final h = math.max(1, (logicalSize.height * dpr).round());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Opaque paper fill — critical so nothing shows through.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()
        ..color = widget.paperColor.withValues(alpha: 1.0)
        ..style = PaintingStyle.fill,
    );
    return recorder.endRecording().toImage(w, h);
  }

  void _resetPointer() {
    _activePointer = null;
    _pointerStartLocal = null;
    _lastPointerLocal = null;
    _lastMoveTime = null;
    _velocityX = 0;
    _axisLockedHorizontal = false;
    _axisLockedVertical = false;
    _turnDirection = null;
    _isRewind = false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isTurning || _settleController.isAnimating) return;
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _pointerStartLocal = event.localPosition;
    _lastPointerLocal = event.localPosition;
    _lastMoveTime = DateTime.now();
    _velocityX = 0;
    _axisLockedHorizontal = false;
    _axisLockedVertical = false;
    _turnDirection = null;
    _isRewind = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isTurning || _settleController.isAnimating) return;
    if (event.pointer != _activePointer) return;
    if (_pointerStartLocal == null || _lastPointerLocal == null) return;

    final now = DateTime.now();
    final dx = event.localPosition.dx - _lastPointerLocal!.dx;
    final dtMs = (_lastMoveTime == null
            ? 16
            : now.difference(_lastMoveTime!).inMilliseconds)
        .clamp(1, 64);
    _velocityX = dx / dtMs;
    _lastPointerLocal = event.localPosition;
    _lastMoveTime = now;

    final total = event.localPosition - _pointerStartLocal!;
    if (_axisLockedVertical) return;

    if (!_axisLockedHorizontal) {
      if (total.dx.abs() < _axisLockSlop && total.dy.abs() < _axisLockSlop) {
        return;
      }
      if (total.dy.abs() > total.dx.abs()) {
        _axisLockedVertical = true;
        return;
      }

      final goingForward = total.dx < 0;
      if (goingForward && !widget.canTurnForward) {
        _axisLockedVertical = true;
        return;
      }
      if (!goingForward && !widget.canTurnBackward) {
        _axisLockedVertical = true;
        return;
      }

      _axisLockedHorizontal = true;
      _turnDirection = goingForward
          ? BookPageTurnDirection.forward
          : BookPageTurnDirection.backward;

      if (_shaderReady && !_shaderFailed && _shader != null) {
        _beginCurl(_turnDirection!, event.localPosition);
      }
      return;
    }

    if (_curl.isCurling) {
      _curl.updateCurl(_curlDrivePos(event.localPosition));
    }
  }

  Future<void> _beginCurl(
    BookPageTurnDirection direction,
    Offset localPos,
  ) async {
    final goingForward = direction == BookPageTurnDirection.forward;
    if (_isCapturing) return;
    _isCapturing = true;
    _isRewind = !goingForward;

    try {
      final size = _widgetSize;
      if (size.isEmpty) return;
      _captureSize = size;

      final rawCurrent = await _captureBoundary(_repaintKey);
      if (rawCurrent == null || !mounted || !_axisLockedHorizontal) return;
      final liveSnap = await _flattenOpaque(rawCurrent);
      final paper = await _paperTexture(size);
      if (!mounted || !_axisLockedHorizontal) {
        liveSnap.dispose();
        paper.dispose();
        return;
      }

      _disposeImages();

      if (goingForward) {
        // Fold forward: current peels away, next chapter underneath.
        setState(() {
          _currentImage = liveSnap;
          _underImage = paper;
          _destinationPreview = null;
        });
        final start = _normalize(_pointerStartLocal ?? localPos);
        // Same geometry always (never mirror to the other edge).
        _curl.startCurl(start, reverse: false);
        _curl.updateCurl(_curlDrivePos(_lastPointerLocal ?? localPos));

        await _loadDestinationOnto(
          direction: direction,
          assignToCurrentLayer: false,
        );
      } else {
        // Rewind: same fold as forward, played backwards.
        // Previous chapter is the curling sheet; current stays underneath.
        // Start the curl immediately (paper placeholder), then swap in the
        // real previous-chapter snapshot — avoids a long blank wait and
        // keeps texture disposal off the active sampler path.
        setState(() {
          _currentImage = paper;
          _underImage = liveSnap;
          _destinationPreview = null;
        });

        final y =
            _normalize(_lastPointerLocal ?? localPos).dy.clamp(0.12, 0.88);
        _curl.startCurl(Offset(1.0, y), reverse: false);
        _curl.updateCurl(_curlDrivePos(_lastPointerLocal ?? localPos));

        await _loadDestinationOnto(
          direction: direction,
          assignToCurrentLayer: true,
        );
      }
    } finally {
      _isCapturing = false;
    }
  }

  /// Captures [loadDestinationPage] and assigns it to the curling sheet
  /// (`assignToCurrentLayer == true`) or the underside.
  Future<bool> _loadDestinationOnto({
    required BookPageTurnDirection direction,
    required bool assignToCurrentLayer,
  }) async {
    try {
      final destination = await widget.loadDestinationPage(direction);
      if (!mounted || destination == null) return false;
      if (!_axisLockedHorizontal && !_curl.isCurling) return false;

      setState(() => _destinationPreview = destination);
      await Future<void>.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final rawDest = await _captureBoundary(_destinationKey);
      if (rawDest == null || !mounted) {
        if (mounted) setState(() => _destinationPreview = null);
        return false;
      }
      final destImage = await _flattenOpaque(rawDest);
      if (!mounted) {
        destImage.dispose();
        return false;
      }

      if (assignToCurrentLayer) {
        if (!_curl.isCurling && !_axisLockedHorizontal) {
          destImage.dispose();
          setState(() => _destinationPreview = null);
          return false;
        }
        setState(() {
          _replaceCurrentImage(destImage);
          _destinationPreview = null;
        });
      } else {
        if (!_curl.isCurling && !_axisLockedHorizontal) {
          destImage.dispose();
          setState(() => _destinationPreview = null);
          return false;
        }
        setState(() {
          _replaceUnderImage(destImage);
          _destinationPreview = null;
        });
      }
      return true;
    } catch (_) {
      if (mounted) setState(() => _destinationPreview = null);
      return false;
    }
  }

  Future<void> _onPointerEnd(PointerEvent event) async {
    if (event.pointer != _activePointer) return;

    if (_axisLockedVertical || !_axisLockedHorizontal) {
      _resetPointer();
      if (_curl.isCurling) {
        _curl.cancelCurl();
        _disposeImages();
        setState(() => _destinationPreview = null);
      }
      return;
    }

    if (!_shaderReady || _shaderFailed || _shader == null) {
      final totalDx =
          (_lastPointerLocal?.dx ?? 0) - (_pointerStartLocal?.dx ?? 0);
      final dir = _turnDirection;
      _resetPointer();
      if (dir != null && totalDx.abs() / math.max(_widgetSize.width, 1) > 0.12) {
        await widget.onTurn(dir);
      }
      return;
    }

    if (!_curl.isCurling) {
      final deadline = DateTime.now().add(const Duration(milliseconds: 500));
      while (_isCapturing && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    }

    if (!_curl.isCurling) {
      _resetPointer();
      _disposeImages();
      setState(() => _destinationPreview = null);
      return;
    }

    final signedVelocity = _isRewind ? _velocityX : -_velocityX;
    // Forward: commit when mostly peeled. Rewind: commit when mostly laid flat.
    final shouldCommit = _isRewind
        ? (_curl.curlProgress <= (1.0 - _commitProgress) ||
            signedVelocity > _commitVelocityPxPerMs)
        : (_curl.curlProgress >= _commitProgress ||
            signedVelocity > _commitVelocityPxPerMs);

    _settleIsCommit = shouldCommit;
    _settleFrom = _curl.curlPosition;
    final y = _curl.curlPosition.dy.clamp(0.12, 0.88);
    if (shouldCommit) {
      // Forward ends peeled off; rewind ends exactly flat at the start anchor.
      // Do NOT go past start (e.g. 1.05) — that flips curl direction and
      // flashes an upside fold at the end of reverse turns.
      _settleTo = _isRewind ? Offset(_curl.startPosition.dx, y) : Offset(-0.45, y);
    } else {
      // Cancel: forward returns to start; rewind returns to left spine.
      _settleTo = _isRewind ? Offset(0.0, y) : _curl.startPosition;
    }

    _isTurning = true;
    if (shouldCommit) HapticFeedback.lightImpact();

    _settleFinishing = false;
    _settleController
      ..stop()
      ..value = 0;
    await _settleController.forward();
  }

  void _onSettleTick() {
    final t = Curves.easeOutCubic.transform(_settleController.value);
    final pos = Offset.lerp(_settleFrom, _settleTo, t)!;
    final y = pos.dy.clamp(0.0, 1.0);
    if (_isRewind && _settleIsCommit) {
      // Flatten only — freeze direction so the sheet never inverts.
      final x = pos.dx.clamp(0.0, _curl.startPosition.dx);
      _curl.updateCurlUnclamped(Offset(x, y), freezeDirection: true);
    } else {
      // Commit settle may peel past the spine; live drag may not.
      _curl.updateCurlUnclamped(Offset(pos.dx, y));
    }
  }

  void _onSettleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_settleFinishing) {
      _finishSettle();
    }
  }

  Future<void> _finishSettle() async {
    _settleFinishing = true;
    final commit = _settleIsCommit;
    final direction = _turnDirection;

    if (commit && direction != null) {
      // Keep the fold overlay up until the new chapter is loaded and painted.
      // Tearing down first flashes the old chapter (bounce), then jumps.
      try {
        await widget.onTurn(direction);
      } catch (_) {}
      if (mounted) {
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
      }
    }

    if (!mounted) return;

    _curl.cancelCurl();
    _disposeImages();
    _destinationPreview = null;
    _settleIsCommit = false;
    _isTurning = false;
    _resetPointer();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final curling = _curl.isCurling &&
        _shader != null &&
        _currentImage != null &&
        _underImage != null;
    final size = _captureSize ?? _widgetSize;

    return ListenableBuilder(
      listenable: _curl,
      builder: (context, _) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Offscreen destination chapter used only for snapshotting.
              if (_destinationPreview != null && size.width > 0)
                Positioned(
                  left: -size.width * 2,
                  top: 0,
                  width: size.width,
                  height: size.height,
                  child: RepaintBoundary(
                    key: _destinationKey,
                    child: ColoredBox(
                      color: widget.paperColor.withValues(alpha: 1),
                      child: _destinationPreview,
                    ),
                  ),
                ),

              // Live chapter — hidden while curling so it can't show through.
              Visibility(
                visible: !curling,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: AbsorbPointer(
                  absorbing: _axisLockedHorizontal || _isTurning,
                  child: ColoredBox(
                    color: widget.paperColor.withValues(alpha: 1),
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: widget.child,
                    ),
                  ),
                ),
              ),

              // Opaque curl composite (current page + destination page only).
              if (curling)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: widget.paperColor.withValues(alpha: 1),
                        child: CustomPaint(
                        painter: PaperCurlPainter(
                          shader: _shader!,
                          controller: _curl,
                          currentPageImage: _currentImage!,
                          nextPageImage: _underImage!,
                          paperColor: widget.paperColor,
                          shadowWidth: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
