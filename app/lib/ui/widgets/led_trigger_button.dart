import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/vj_tokens.dart';

/// Déclencheur à lentille (Flash, Drop, Scène) : pad enfoncé dans la façade,
/// touche mécanique, lentille qui s'allume à l'appui puis retombe.
class LedTriggerButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool compact; // 84 × 64 dans le tiroir, sinon 86 × 84
  /// Durée d'éclairage après l'appui (retombée de la lentille).
  final Duration litDuration;
  const LedTriggerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.litDuration = const Duration(milliseconds: 450),
  });

  @override
  State<LedTriggerButton> createState() => _LedTriggerButtonState();
}

class _LedTriggerButtonState extends State<LedTriggerButton> {
  bool _held = false;
  bool _lit = false;
  Timer? _off;

  @override
  void dispose() {
    _off?.cancel();
    super.dispose();
  }

  void _press() {
    HapticFeedback.lightImpact();
    _off?.cancel();
    setState(() {
      _held = true;
      _lit = true;
    });
    widget.onPressed();
  }

  void _release() {
    setState(() => _held = false);
    _off?.cancel();
    _off = Timer(widget.litDuration, () {
      if (mounted) setState(() => _lit = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.compact ? 84.0 : 86.0;
    final h = widget.compact ? 64.0 : 84.0;
    final down = _held || _lit;
    return Semantics(
      label: down ? '${widget.label}, enfoncé' : widget.label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: Container(
          width: w,
          height: h,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(widget.compact ? 8 : VjDims.padRadius),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0F11), Color(0xFF1C1C1F)],
            ),
            boxShadow: [
              const BoxShadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Color(0xE6000000),
                  blurStyle: BlurStyle.inner),
              BoxShadow(
                  offset: const Offset(0, 1),
                  color: Colors.white.withValues(alpha: .08)),
              if (_lit)
                BoxShadow(
                    blurRadius: 26,
                    color: const Color(0xFFFF9628).withValues(alpha: .22)),
            ],
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            margin: EdgeInsets.only(top: down ? 5 : 0, bottom: down ? 0 : 5),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.compact ? 5 : 6),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: down
                    ? const [Color(0xFF434448), Color(0xFF28292C)]
                    : const [Color(0xFF48494D), Color(0xFF2A2B2E)],
              ),
              boxShadow: [
                BoxShadow(
                    offset: Offset(0, down ? 1 : 6), color: const Color(0xFF0E0E10)),
                BoxShadow(
                    offset: Offset(0, down ? 2 : 8),
                    blurRadius: down ? 3 : 10,
                    color: Colors.black.withValues(alpha: .55)),
                BoxShadow(
                    offset: const Offset(0, 1),
                    color: Colors.white.withValues(alpha: down ? .12 : .2),
                    blurStyle: BlurStyle.inner),
              ],
            ),
            child: _Lens(label: widget.label, on: _lit, compact: widget.compact),
          ),
        ),
      ),
    );
  }
}

class _Lens extends StatelessWidget {
  final String label;
  final bool on;
  final bool compact;
  const _Lens({required this.label, required this.on, required this.compact});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 3 : VjDims.lensRadius),
        gradient: on
            ? const RadialGradient(
                center: Alignment(0, -.2),
                radius: 1.1,
                colors: VjColors.lensOn,
                stops: [0, .38, .76, 1],
              )
            : const RadialGradient(
                center: Alignment(0, -.4),
                radius: 1.2,
                colors: [VjColors.lensOffHi, VjColors.lensOffLo],
                stops: [0, .78],
              ),
        boxShadow: on
            ? [
                BoxShadow(
                    blurRadius: 16,
                    spreadRadius: 3,
                    color: const Color(0xFFFFA032).withValues(alpha: .55)),
                BoxShadow(
                    blurRadius: 38,
                    color: const Color(0xFFFF821E).withValues(alpha: .35)),
              ]
            : const [
                BoxShadow(
                    offset: Offset(0, 2),
                    blurRadius: 6,
                    color: Color(0x99000000),
                    blurStyle: BlurStyle.inner),
              ],
      ),
      child: Text(
        label.toUpperCase(),
        style: VjText.lensLabel.copyWith(
          fontSize: compact ? 13 : 15,
          letterSpacing: (compact ? 13 : 15) * .16,
          fontWeight: on ? FontWeight.w700 : FontWeight.w600,
          color: on ? VjColors.lensOnText : VjColors.lensText,
        ),
      ),
    );
  }
}
