import 'package:flutter/animation.dart';

/// Approved UI motion values. Network timeouts and fixture delays do not
/// belong here.
abstract final class LegalHubMotion {
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationBase = Duration(milliseconds: 300);
  static const Duration debounce = Duration(milliseconds: 300);
  static const Curve curveStandard = Curves.easeOut;
}
