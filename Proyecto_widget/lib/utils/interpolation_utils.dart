import '../models/biomarker.dart';

class InterpolationUtils {
  static bool isBad(String flag) =>
      flag.contains('device_not') ||
      flag.contains('low_signal') ||
      flag.contains('motion');

  /// Returns parallel lists of length == data.length:
  /// - [original]: valid (non-bad) values; null for bad/missing points.
  /// - [interpolated]: gaps filled according to [method] ('ffill'|'linear'|'spline').
  static ({List<double?> original, List<double?> interpolated}) compute(
    List<Biomarker> data,
    String method,
  ) {
    if (data.isEmpty) return (original: [], interpolated: []);

    final n = data.length;
    final original     = List<double?>.filled(n, null);
    final interpolated = List<double?>.filled(n, null);

    for (int i = 0; i < n; i++) {
      if (!isBad(data[i].qualityFlag) && data[i].value != null) {
        original[i]     = data[i].value;
        interpolated[i] = data[i].value;
      }
    }

    if (method == 'ffill') {
      _ffill(interpolated, n);
    } else if (method == 'spline') {
      _spline(interpolated, n);
    } else {
      _linear(interpolated, n);
    }

    return (original: original, interpolated: interpolated);
  }

  static void _ffill(List<double?> out, int n) {
    double? last;
    for (int i = 0; i < n; i++) {
      if (out[i] != null) {
        last = out[i];
      } else if (last != null) {
        out[i] = last;
      }
    }
  }

  static void _linear(List<double?> out, int n) {
    int i = 0;
    while (i < n) {
      if (out[i] != null) { i++; continue; }
      final prev = i - 1;
      int next = i;
      while (next < n && out[next] == null) { next++; }
      if (prev >= 0 && next < n) {
        final span = (next - prev).toDouble();
        for (int j = prev + 1; j < next; j++) {
          out[j] = out[prev]! + (out[next]! - out[prev]!) * (j - prev) / span;
        }
        i = next;
      } else if (next < n) {
        for (int j = 0; j < next; j++) { out[j] ??= out[next]; }
        i = next + 1;
      } else if (prev >= 0) {
        for (int j = i; j < n; j++) { out[j] ??= out[prev]; }
        break;
      } else {
        break;
      }
    }
  }

  // Preview uses linear; true cubic spline is applied by pandas on server-side export.
  static void _spline(List<double?> out, int n) => _linear(out, n);
}
