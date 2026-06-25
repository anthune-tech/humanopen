import 'dart:math';
import 'package:flutter/material.dart';

enum AiState { idle, loading, generating, error }

class GradientBackground extends StatefulWidget {
  final AiState aiState;
  final Widget child;

  const GradientBackground({
    super.key,
    required this.aiState,
    required this.child,
  });

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 8),
    )..repeat();
    _controller.addListener(() {
      setState(() => _phase = _controller.value);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speed = widget.aiState == AiState.generating ? 4.0 :
                  widget.aiState == AiState.loading ? 2.0 : 1.0;
    _controller.duration = Duration(
        milliseconds: (8000 / speed).toInt());

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: _buildGradient(),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  LinearGradient _buildGradient() {
    final t = _phase * 2 * pi;
    final intensity = widget.aiState == AiState.generating ? 0.6 :
                      widget.aiState == AiState.loading ? 0.8 : 0.4;
    final pulse = sin(t) * 0.15 + 0.85;

    return LinearGradient(
      begin: Alignment(sin(t) * 0.3, cos(t) * 0.3),
      end: Alignment(sin(t + pi) * 0.3, cos(t + pi) * 0.3),
      colors: [
        Color.fromRGBO(10, 12, 28, 1.0),
        Color.fromRGBO(
          (20 + 20 * sin(t) * intensity).toInt(),
          (15 + 15 * cos(t * 0.7) * intensity).toInt(),
          (35 + 25 * sin(t * 1.3) * intensity).toInt(),
          (0.85 * pulse).toDouble(),
        ),
        Color.fromRGBO(
          (15 + 15 * cos(t * 0.5) * intensity).toInt(),
          (25 + 20 * sin(t * 0.8) * intensity).toInt(),
          (45 + 30 * cos(t * 1.1) * intensity).toInt(),
          (0.7 * pulse).toDouble(),
        ),
      ],
    );
  }
}
