import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

class Vector2 {
  final double x;
  final double y;

  const Vector2(this.x, this.y);

  static Vector2 zero() => const Vector2(0, 0);

  double get length => sqrt(x * x + y * y);

  Vector2 normalized() {
    if (length > 0) {
      return Vector2(x / length, y / length);
    }
    return Vector2(0, 0);
  }
}

class UnifiedJoystick extends StatefulWidget {
  final Function(double dx, double dy) onMove;
  final bool rightSide;
  final double size;
  final Color baseColor;
  final Color stickColor;
  final Color borderColor;
  final double deadzone;

  const UnifiedJoystick({
    super.key,
    required this.onMove,
    this.rightSide = false,
    this.size = 180,
    this.baseColor = Colors.black54,
    this.stickColor = Colors.white54,
    this.borderColor = Colors.white30,
    this.deadzone = 0.03,
  });

  @override
  State<UnifiedJoystick> createState() => _UnifiedJoystickState();
}

class _UnifiedJoystickState extends State<UnifiedJoystick> {
  Vector2 _direction = Vector2.zero();
  bool _isTouching = false;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: false,
      child: Container(
        height: widget.size,
        width: widget.size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: JoystickArea(
          mode: JoystickMode.all,
          period: const Duration(milliseconds: 16),
          listener: (details) {
            double dx = details.x;
            double dy = details.y;
            if (sqrt(dx * dx + dy * dy) < widget.deadzone) {
              if (_isTouching) {
                dx = 0;
                dy = 0;
              } else {
                return;
              }
            } else {
              _isTouching = true;
            }
            if (dx != _direction.x || dy != _direction.y) {
              setState(() {
                _direction = Vector2(dx, dy);
              });
              widget.onMove(dx, dy);
            }
          },
          onStickDragStart: (_) {
            setState(() => _isTouching = true);
          },
          onStickDragEnd: () {
            setState(() {
              _isTouching = false;
              _direction = Vector2.zero();
            });
            widget.onMove(0, 0);
          },
          base: Container(
            width: widget.size * 0.7,
            height: widget.size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.baseColor,
              border: Border.all(color: widget.borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          stick: Container(
            width: widget.size * 0.35,
            height: widget.size * 0.35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.stickColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: widget.size * 0.12,
                height: widget.size * 0.12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PositionedJoystick extends StatelessWidget {
  final Function(double dx, double dy) onMove;
  final bool rightSide;
  final double size;
  final double bottom;
  final double sideOffset;
  final Color baseColor;
  final Color stickColor;
  final Color borderColor;
  final double deadzone;

  const PositionedJoystick({
    super.key,
    required this.onMove,
    this.rightSide = false,
    this.size = 180,
    this.bottom = 20,
    this.sideOffset = 20,
    this.baseColor = Colors.black54,
    this.stickColor = Colors.white54,
    this.borderColor = Colors.white30,
    this.deadzone = 0.03,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive positioning
    final screenSize = MediaQuery.of(context).size;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    // Calculate responsive size based on screen width
    final responsiveSize = screenSize.width * 0.25;
    final finalSize = responsiveSize.clamp(140.0, 180.0);
    
    // Calculate responsive bottom padding - ensure it's below game board
    final responsiveBottom = safeAreaBottom + 40.0;
    
    // Calculate responsive side offset - ensure it's outside game board
    final responsiveSideOffset = screenSize.width * 0.08;

    return Positioned(
      bottom: responsiveBottom,
      right: rightSide ? responsiveSideOffset : null,
      left: rightSide ? null : responsiveSideOffset,
      child: UnifiedJoystick(
        onMove: onMove,
        rightSide: rightSide,
        size: finalSize,
        baseColor: baseColor,
        stickColor: stickColor,
        borderColor: borderColor,
        deadzone: deadzone,
      ),
    );
  }
}
