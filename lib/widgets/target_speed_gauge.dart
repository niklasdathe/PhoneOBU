import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/obu_snapshot.dart';
import '../theme/obu_theme.dart';

class TargetSpeedGauge extends StatelessWidget {
  const TargetSpeedGauge({
    required this.speedKmh,
    required this.glosa,
    super.key,
  });

  final double speedKmh;
  final GlosaRecommendation glosa;

  @override
  Widget build(BuildContext context) {
    final target = glosa.recommendedSpeedKmh;
    final delta = target == null ? null : target - speedKmh;
    final semantic = target == null
        ? 'Current speed ' +
            speedKmh.round().toString() +
            ' kilometers per hour. Green wave recommendation unavailable. ' +
            glosa.statusDetail
        : 'Current speed ' +
            speedKmh.round().toString() +
            ' kilometers per hour. Target speed ' +
            target.round().toString() +
            ' for the next green light.';
    return Semantics(
      label: semantic,
      child: SizedBox(
        width: 246,
        height: 216,
        child: CustomPaint(
          painter: _GaugePainter(
            speedKmh: speedKmh,
            targetSpeedKmh: target,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  speedKmh.round().toString(),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: ObuColors.ink,
                        fontSize: 68,
                        height: 0.95,
                      ),
                ),
                Text(
                  'km/h',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: ObuColors.muted,
                      ),
                ),
                const SizedBox(height: 11),
                Container(
                  constraints: const BoxConstraints(maxWidth: 228),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: target == null
                          ? ObuColors.line
                          : ObuColors.green.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: target == null
                              ? ObuColors.muted
                              : ObuColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _label(delta),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (glosa.secondsToChange != null) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    _countdownLabel(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ObuColors.muted,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _label(double? delta) {
    if (delta == null) return 'GLOSA unavailable';
    if (delta > 0.5) {
      return '+' + delta.toStringAsFixed(1) + ' km/h to green';
    }
    if (delta < -0.5) {
      return delta.toStringAsFixed(1) + ' km/h to green';
    }
    return glosa.targetsLaterGreen ? 'Later green pace' : 'Green pace';
  }

  String _countdownLabel() {
    final seconds = glosa.secondsToChange!.ceil();
    if (glosa.targetsLaterGreen) {
      return 'Next green in ' + seconds.toString() + ' s';
    }
    final state = glosa.signalState?.toLowerCase() ?? '';
    if (state.contains('green') || state.contains('permissive')) {
      return 'Changes in ' + seconds.toString() + ' s';
    }
    return 'Green in ' + seconds.toString() + ' s';
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.speedKmh,
    required this.targetSpeedKmh,
  });

  final double speedKmh;
  final double? targetSpeedKmh;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 108);
    const radius = 94.0;
    const start = math.pi * 1.17;
    const sweep = math.pi * 2 / 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = const Color(0xFFD4D6D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, track);

    final displayMaximum = math.max(
      35,
      math.max(speedKmh, targetSpeedKmh ?? 0),
    );
    final speedFraction =
        (speedKmh / displayMaximum).clamp(0.0, 1.0).toDouble();
    final active = Paint()
      ..color =
          targetSpeedKmh == null ? ObuColors.ink : ObuColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep * speedFraction, false, active);

    final target = targetSpeedKmh;
    if (target == null) return;
    final targetFraction =
        (target / displayMaximum).clamp(0.0, 1.0).toDouble();
    final targetAngle = start + sweep * targetFraction;
    final outer = Offset(
      center.dx + math.cos(targetAngle) * (radius + 12),
      center.dy + math.sin(targetAngle) * (radius + 12),
    );
    final inner = Offset(
      center.dx + math.cos(targetAngle) * (radius - 13),
      center.dy + math.sin(targetAngle) * (radius - 13),
    );
    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..color = ObuColors.ink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.speedKmh != speedKmh ||
        oldDelegate.targetSpeedKmh != targetSpeedKmh;
  }
}
