/// Modular noise-reduction / signal pre-processing utilities used by the
/// diagnostic pipeline to smooth noisy sensor data before analysis.
///
/// The heart-rate diagnostic feeds raw camera luminance samples through
/// [NoiseReduction.apply] on every frame, while [NoiseReduction.filter] can be
/// used off-line to clean a complete buffer (e.g. a recorded audio signal).
///
/// Filtering is toggled through [DiagnosticSettings.noiseReductionEnabled] so
/// it can be disabled globally without touching the diagnostic workflow.
class NoiseReduction {
  /// Number of samples averaged by the moving-average filter.
  final int windowSize;

  /// Whether filtering is currently applied. Defaults to the global setting.
  bool enabled;

  final List<double> _window = <double>[];

  NoiseReduction({this.windowSize = 5, bool? enabled})
    : assert(windowSize > 0),
      enabled = enabled ?? DiagnosticSettings.noiseReductionEnabled;

  /// Applies the moving-average filter to a single incoming [sample] and
  /// returns the smoothed value. Keeps internal state between calls.
  double apply(double sample) {
    if (!enabled || windowSize <= 1) {
      return sample;
    }

    _window.add(sample);
    if (_window.length > windowSize) {
      _window.removeAt(0);
    }

    var sum = 0.0;
    for (final value in _window) {
      sum += value;
    }
    return sum / _window.length;
  }

  /// Clears the internal filter state, e.g. when a new signal starts.
  void reset() => _window.clear();

  /// Filters a complete [samples] buffer off-line and returns a new list,
  /// leaving the input untouched.
  static List<double> filter(List<double> samples, {int windowSize = 5}) {
    if (windowSize <= 1 || samples.isEmpty) {
      return List<double>.of(samples);
    }

    final output = <double>[];
    final window = <double>[];

    for (final sample in samples) {
      window.add(sample);
      if (window.length > windowSize) {
        window.removeAt(0);
      }

      var sum = 0.0;
      for (final value in window) {
        sum += value;
      }
      output.add(sum / window.length);
    }

    return output;
  }

  /// Convenience wrapper for 16-bit little-endian PCM audio buffers.
  ///
  /// Decodes [pcmBytes] into samples, applies [filter] and returns a filtered
  /// copy with the same byte length. Handy for pre-processing raw audio from
  /// the lung diagnostic before it is analysed.
  static List<int> filterPcm16(List<int> pcmBytes, {int windowSize = 5}) {
    if (pcmBytes.length < 2) {
      return List<int>.of(pcmBytes);
    }

    final samples = <double>[];
    for (var i = 0; i + 1 < pcmBytes.length; i += 2) {
      var value = pcmBytes[i] | (pcmBytes[i + 1] << 8);
      if (value >= 0x8000) {
        value -= 0x10000;
      }
      samples.add(value.toDouble());
    }

    final filtered = filter(samples, windowSize: windowSize);
    final output = <int>[];
    for (final value in filtered) {
      final clamped = value.round().clamp(-32768, 32767).toInt();
      output.add(clamped & 0xFF);
      output.add((clamped >> 8) & 0xFF);
    }
    return output;
  }
}

/// Global switches for the diagnostic pre-processing pipeline.
class DiagnosticSettings {
  /// When false, noise reduction is bypassed everywhere it is applied.
  static bool noiseReductionEnabled = true;

  /// Default moving-average window used when no size is specified.
  static const int defaultNoiseWindow = 5;
}
