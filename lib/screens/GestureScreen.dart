// letter_gesture_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math' as math;

class LetterGestureController {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isTtsInitialized = false;

  // Initialize TTS
  static Future<void> initializeTts() async {
    if (!_isTtsInitialized) {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.6);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
    }
  }

  // Speak text with TTS
  static Future<void> speak(String text) async {
    await initializeTts();
    await _flutterTts.speak(text);
  }
}

// Letter drawing gesture detector
class LetterGestureDetector extends StatefulWidget {
  final Widget child;
  final Function(String letter) onLetterDrawn;
  final Map<String, VoidCallback> letterActions;
  final bool enableVoiceGuidance;
  final double sensitivity;

  const LetterGestureDetector({
    Key? key,
    required this.child,
    required this.onLetterDrawn,
    this.letterActions = const {},
    this.enableVoiceGuidance = true,
    this.sensitivity = 50.0,
  }) : super(key: key);

  @override
  State<LetterGestureDetector> createState() => _LetterGestureDetectorState();
}

class _LetterGestureDetectorState extends State<LetterGestureDetector> {
  List<Offset> _points = [];
  bool _isDrawing = false;
  String? _detectedLetter;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Letter drawing area',
      hint:
          'Draw letters on screen to trigger actions. ${_getAvailableActionsHint()}',
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDrawing = true;
            _points.clear();
            _points.add(details.localPosition);
          });
          if (widget.enableVoiceGuidance) {
            HapticFeedback.lightImpact();
          }
        },
        onPanUpdate: (details) {
          setState(() {
            _points.add(details.localPosition);
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDrawing = false;
          });
          _recognizeLetter();
        },
        child: CustomPaint(
          painter: _isDrawing ? LetterPainter(_points) : null,
          child: widget.child,
        ),
      ),
    );
  }

  String _getAvailableActionsHint() {
    if (widget.letterActions.isEmpty) return '';
    final letters = widget.letterActions.keys.join(', ');
    return 'Available letters: $letters';
  }

  void _recognizeLetter() {
    if (_points.length < 3) return;

    final letter = _detectLetterFromPoints(_points);
    if (letter != null) {
      _detectedLetter = letter;
      widget.onLetterDrawn(letter);

      if (widget.enableVoiceGuidance) {
        LetterGestureController.speak('Letter $letter detected');
        HapticFeedback.mediumImpact();
      }

      // Execute action if available
      if (widget.letterActions.containsKey(letter)) {
        widget.letterActions[letter]!();
      }
    }

    // Clear points after recognition
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _points.clear();
      });
    });
  }

  String? _detectLetterFromPoints(List<Offset> points) {
    if (points.length < 3) return null;

    // Normalize points to a bounding box
    final normalizedPoints = _normalizePoints(points);

    // Check for different letter patterns
    if (_isLetterL(normalizedPoints)) return 'L';
    if (_isLetterH(normalizedPoints)) return 'H';
    if (_isLetterV(normalizedPoints)) return 'V';
    if (_isLetterA(normalizedPoints)) return 'A';
    if (_isLetterE(normalizedPoints)) return 'E';
    if (_isLetterC(normalizedPoints)) return 'C';
    if (_isLetterO(normalizedPoints)) return 'O';
    if (_isLetterS(normalizedPoints)) return 'S';
    if (_isLetterM(normalizedPoints)) return 'M';
    if (_isLetterP(normalizedPoints)) return 'P';
    if (_isLetterR(normalizedPoints)) return 'R';
    if (_isLetterT(normalizedPoints)) return 'T';
    if (_isLetterI(normalizedPoints)) return 'I';
    if (_isLetterU(normalizedPoints)) return 'U';

    return null;
  }

  List<Offset> _normalizePoints(List<Offset> points) {
    if (points.isEmpty) return [];

    // Find bounding box
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    final width = maxX - minX;
    final height = maxY - minY;

    if (width == 0 || height == 0) return points;

    // Normalize to 0-1 range
    return points
        .map((point) => Offset(
              (point.dx - minX) / width,
              (point.dy - minY) / height,
            ))
        .toList();
  }

  // Letter recognition methods
  bool _isLetterL(List<Offset> points) {
    // L shape: starts high, goes down, then goes right
    if (points.length < 6) return false;

    final start = points.first;
    final middle = points[points.length ~/ 2];
    final end = points.last;

    // Check if it starts from top-left area
    bool startsTop = start.dy < 0.3;
    // Goes down first
    bool goesDown = middle.dy > start.dy + 0.3;
    // Then goes right
    bool goesRight = end.dx > middle.dx + 0.3;

    return startsTop && goesDown && goesRight;
  }

  bool _isLetterH(List<Offset> points) {
    // H shape: vertical line, horizontal line, vertical line
    if (points.length < 8) return false;

    // Look for pattern: down, right, up or down
    final directions = _getDirections(points);

    // Simple H detection: should have vertical movements and a horizontal connection
    int verticalMoves = 0;
    int horizontalMoves = 0;

    for (final dir in directions) {
      if (dir == 'up' || dir == 'down') verticalMoves++;
      if (dir == 'left' || dir == 'right') horizontalMoves++;
    }

    return verticalMoves >= 2 && horizontalMoves >= 1;
  }

  bool _isLetterV(List<Offset> points) {
    // V shape: starts top-left, goes down-right to center, then up-right
    if (points.length < 5) return false;

    final quarter = points.length ~/ 4;
    final half = points.length ~/ 2;
    final threeQuarter = (points.length * 3) ~/ 4;

    final start = points.first;
    final bottomPoint = points[half];
    final end = points.last;

    // Should start high, go to bottom middle, then go up
    bool startsHigh = start.dy < 0.4;
    bool goesToBottom = bottomPoint.dy > 0.6;
    bool endsHigh = end.dy < 0.4;
    bool vShape = start.dx < bottomPoint.dx && bottomPoint.dx < end.dx;

    return startsHigh && goesToBottom && endsHigh && vShape;
  }

  bool _isLetterA(List<Offset> points) {
    // A shape: up and to the right, down and to the right, then a horizontal line
    if (points.length < 6) return false;

    final directions = _getDirections(points);

    // Look for up-right, down-right pattern with horizontal connection
    bool hasUpRight = directions.contains('up-right');
    bool hasDownRight = directions.contains('down-right');
    bool hasHorizontal =
        directions.contains('right') || directions.contains('left');

    return hasUpRight && hasDownRight && hasHorizontal;
  }

  bool _isLetterE(List<Offset> points) {
    // E shape: vertical line with horizontal lines
    if (points.length < 6) return false;

    final directions = _getDirections(points);

    // Should have multiple horizontal movements and vertical movements
    int horizontalCount = 0;
    int verticalCount = 0;

    for (final dir in directions) {
      if (dir == 'left' || dir == 'right') horizontalCount++;
      if (dir == 'up' || dir == 'down') verticalCount++;
    }

    return horizontalCount >= 2 && verticalCount >= 1;
  }

  bool _isLetterC(List<Offset> points) {
    // C shape: curved from top to bottom, open on the right
    if (points.length < 4) return false;

    final start = points.first;
    final end = points.last;

    // Should start and end on the left side, curve around
    bool startsLeft = start.dx < 0.4;
    bool endsLeft = end.dx < 0.4;
    bool curvesRight = points.any((p) => p.dx > 0.6);

    return startsLeft && endsLeft && curvesRight;
  }

  bool _isLetterO(List<Offset> points) {
    // O shape: circular motion
    if (points.length < 8) return false;

    // Check if path is roughly circular
    final center = Offset(0.5, 0.5);
    double avgDistance = 0;
    for (final point in points) {
      avgDistance += (point - center).distance;
    }
    avgDistance /= points.length;

    // Check if all points are roughly the same distance from center
    int closeToAvg = 0;
    for (final point in points) {
      if (((point - center).distance - avgDistance).abs() < 0.2) {
        closeToAvg++;
      }
    }

    return closeToAvg > points.length * 0.7;
  }

  bool _isLetterS(List<Offset> points) {
    // S shape: curves in opposite directions
    if (points.length < 6) return false;

    final directions = _getDirections(points);

    // S should have multiple direction changes
    int directionChanges = 0;
    for (int i = 1; i < directions.length; i++) {
      if (directions[i] != directions[i - 1]) {
        directionChanges++;
      }
    }

    return directionChanges >= 3;
  }

  bool _isLetterM(List<Offset> points) {
    // M shape: up, down, up, down pattern
    if (points.length < 6) return false;

    final directions = _getDirections(points);

    // Look for alternating up/down pattern
    int upCount = 0;
    int downCount = 0;

    for (final dir in directions) {
      if (dir.contains('up')) upCount++;
      if (dir.contains('down')) downCount++;
    }

    return upCount >= 2 && downCount >= 2;
  }

  bool _isLetterP(List<Offset> points) {
    // P shape: vertical line with horizontal lines at top
    if (points.length < 5) return false;

    final start = points.first;
    final end = points.last;

    // Should start and end on left side, with movement to right in upper portion
    bool startsLeft = start.dx < 0.3;
    bool endsLeft = end.dx < 0.3;
    bool hasRightMovement =
        points.sublist(0, points.length ~/ 2).any((p) => p.dx > 0.6);

    return startsLeft && endsLeft && hasRightMovement;
  }

  bool _isLetterR(List<Offset> points) {
    // R shape: similar to P but with diagonal line at bottom
    if (points.length < 6) return false;

    final directions = _getDirections(points);

    // Should have vertical, horizontal, and diagonal movements
    bool hasVertical = directions.any((d) => d == 'up' || d == 'down');
    bool hasHorizontal = directions.any((d) => d == 'left' || d == 'right');
    bool hasDiagonal = directions.any((d) => d.contains('-'));

    return hasVertical && hasHorizontal && hasDiagonal;
  }

  bool _isLetterT(List<Offset> points) {
    // T shape: horizontal line followed by vertical line
    if (points.length < 4) return false;

    final directions = _getDirections(points);

    // Should start with horizontal movement, then vertical
    bool startsHorizontal = directions.isNotEmpty &&
        (directions.first == 'left' || directions.first == 'right');
    bool hasVertical = directions.any((d) => d == 'up' || d == 'down');

    return startsHorizontal && hasVertical;
  }

  bool _isLetterI(List<Offset> points) {
    // I shape: simple vertical line
    if (points.length < 3) return false;

    final start = points.first;
    final end = points.last;

    // Should be mostly vertical
    bool isVertical = (end.dy - start.dy).abs() > (end.dx - start.dx).abs() * 2;

    return isVertical;
  }

  bool _isLetterU(List<Offset> points) {
    // U shape: down, curve, up
    if (points.length < 5) return false;

    final start = points.first;
    final middle = points[points.length ~/ 2];
    final end = points.last;

    // Should start high, go to bottom, end high
    bool startsHigh = start.dy < 0.4;
    bool bottomLow = middle.dy > 0.6;
    bool endsHigh = end.dy < 0.4;
    bool uShape = start.dx < end.dx; // ends to the right of start

    return startsHigh && bottomLow && endsHigh && uShape;
  }

  List<String> _getDirections(List<Offset> points) {
    List<String> directions = [];

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      final dx = curr.dx - prev.dx;
      final dy = curr.dy - prev.dy;

      if (dx.abs() < 0.05 && dy.abs() < 0.05) continue; // Too small movement

      if (dx.abs() > dy.abs()) {
        directions.add(dx > 0 ? 'right' : 'left');
      } else {
        directions.add(dy > 0 ? 'down' : 'up');
      }
    }

    return directions;
  }
}

// Painter to show the drawing path
class LetterPainter extends CustomPainter {
  final List<Offset> points;

  LetterPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Screen wrapper with letter gesture control
class LetterGestureScreen extends StatefulWidget {
  final Widget child;
  final String screenName;
  final Map<String, VoidCallback> letterActions;
  final VoidCallback? onBack;

  const LetterGestureScreen({
    Key? key,
    required this.child,
    required this.screenName,
    required this.letterActions,
    this.onBack,
  }) : super(key: key);

  @override
  State<LetterGestureScreen> createState() => _LetterGestureScreenState();
}

class _LetterGestureScreenState extends State<LetterGestureScreen> {
  String? _lastDetectedLetter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceScreen();
    });
  }

  void _announceScreen() {
    final availableLetters = widget.letterActions.keys.join(', ');
    LetterGestureController.speak(
        'Opening ${widget.screenName}. Draw letters on screen to navigate. Available letters: $availableLetters');
  }

  @override
  Widget build(BuildContext context) {
    return LetterGestureDetector(
      letterActions: widget.letterActions,
      onLetterDrawn: (letter) {
        setState(() {
          _lastDetectedLetter = letter;
        });
      },
      child: Scaffold(
        body: Stack(
          children: [
            widget.child,
            // Show last detected letter
            if (_lastDetectedLetter != null)
              Positioned(
                top: 50,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Last: $_lastDetectedLetter',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
