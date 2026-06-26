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

  static const _stateColors = {
    AiState.idle: [Color(0xFF1E1B4B), Color(0xFF6D28D9), Color(0xFFBE185D)],
    AiState.loading: [Color(0xFF1E1B4B), Color(0xFF7C3AED), Color(0xFFDB2777)],
    AiState.generating: [Color(0xFF2E1065), Color(0xFF8B5CF6), Color(0xFFEC4899)],
    AiState.error: [Color(0xFF1E1B4B), Color(0xFF991B1B), Color(0xFFBE123C)],
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speed = switch (widget.aiState) {
      AiState.generating => 4.0,
      AiState.loading => 2.0,
      _ => 1.0,
    };
    _controller.duration = Duration(milliseconds: (8000 / speed).toInt());

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
    final phase = _controller.value * 2 * pi;
    final pulse = sin(phase) * 0.12 + 0.88;

    final colors = _stateColors[widget.aiState]!;
    final wobble = sin(phase * 0.5) * 0.15 + 0.5;

    return LinearGradient(
      begin: Alignment(-0.3 + sin(phase) * 0.2, -0.3 + cos(phase) * 0.2),
      end: Alignment(0.3 - sin(phase) * 0.2, 0.3 - cos(phase) * 0.2),
      colors: [
        colors[0].withValues(alpha: pulse),
        Color.lerp(colors[1], colors[2], wobble)!.withValues(alpha: pulse * 0.9),
      ],
    );
  }
}
