import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:smart_health_monitor/components/noise_reduction.dart';
/// Stethoscope-audio cleanup pipeline for the lung diagnostic.
///
/// Convention floors are the worst case: crowd chatter, PA speakers and
/// footsteps drown the faint breath sounds picked up by the chest piece.
/// [StethoAudio.cleanFile] runs the exported WAV recording through a
/// three-stage chain tuned for that scenario:
///
/// 1. A 60 Hz high-pass removes rumble (HVAC, footsteps, sub-bass from PA).
/// 2. A 3.8 kHz low-pass trims clatter above the lung band (crackles and
///    wheezes live below ~2 kHz).
/// 3. An adaptive noise gate estimates the ambient floor from the quietest
///    moments of the take and attenuates the gaps between breaths so the
///    analyser (and the doctor/demo listener) mostly hears the lung signal.
/// 4. Peak normalisation restores level lost to the filtering.
///
/// The processed recording is written back over the original file. Every
/// stage can be bypassed via [DiagnosticSettings.noiseReductionEnabled] or a
/// thrown error is treated as "keep the original take" so a convention demo
/// never loses a recording.
class StethoAudio {
  StethoAudio._();

  /// Upper limit of the lung band. Crackles/wheezes concentrate below 2 kHz;
  /// anything above is mostly convention noise.
  static const double lungBandHighpassHz = 60.0;
  static const double lungBandLowpassHz = 3800.0;

  /// Gate thresholds in units of the measured ambient floor RMS.
  static const double gateOpenFactor = 1.30;
  static const double gateClosedGain = 0.15;

  /// Peak target after normalisation, as a fraction of full scale.
  static const double normaliseTarget = 0.9;

  /// Cleans a recorded WAV file in place. Returns true when a cleaned take
  /// was written, false when the original was kept (unsupported format,
  /// filtering disabled, or a failure occurred).
  static Future<bool> cleanFile(String path) async {
    if (!DiagnosticSettings.noiseReductionEnabled) {
      return false;
    }
    final file = File(path);
    if (!await file.exists()) {
      return false;
    }

    try {
      final bytes = await file.readAsBytes();
      final take = WavPcm16.decode(bytes);
      if (take.samples.isEmpty) {
        return false;
      }

      final cleaned = enhance(take.samples, take.sampleRate);
      final encoded = WavPcm16.encode(
        cleaned,
        take.sampleRate,
        take.numChannels,
      );
      await file.writeAsBytes(encoded, flush: true);
      return true;
    } catch (_) {
      // Never lose a recording because of a processing error.
      return false;
    }
  }

  /// Runs the full band-limit + gate + normalise chain over [samples].
  static List<double> enhance(List<double> samples, int sampleRate) {
    if (samples.isEmpty) {
      return List<double>.of(samples);
    }

    var signal = List<double>.of(samples);
    // 4th-order Butterworth: 24 dB/oct roll-off, strong convention-floor
    // rejection while staying flat across the lung band.
    for (var stage = 0; stage < 2; stage++) {
      signal = _BiquadFilter.highPass(lungBandHighpassHz, sampleRate)
          .process(signal);
      signal = _BiquadFilter.lowPass(lungBandLowpassHz, sampleRate)
          .process(signal);
    }
    signal = AdaptiveNoiseGate(
      sampleRate: sampleRate,
      openFactor: gateOpenFactor,
      closedGain: gateClosedGain,
    ).process(signal);
    return _normalise(signal, normaliseTarget);
  }

  static List<double> _normalise(List<double> samples, double target) {
    var peak = 0.0;
    for (final sample in samples) {
      final magnitude = sample.abs();
      if (magnitude > peak) {
        peak = magnitude;
      }
    }
    if (peak <= 1e-9 || peak >= target) {
      return samples;
    }
    final gain = target / peak;
    return [for (final sample in samples) sample * gain];
  }
}

/// Minimal RBJ biquad section used by the stethoscope band filters.
class _BiquadFilter {
  final double b0, b1, b2, a1, a2;
  double _x1 = 0, _x2 = 0;

  _BiquadFilter._(this.b0, this.b1, this.b2, this.a1, this.a2);

  factory _BiquadFilter.highPass(double cutoffHz, int sampleRate) {
    return _BiquadFilter._design(
      f0: cutoffHz.clamp(1.0, sampleRate / 2 - 1).toDouble(),
      sampleRate: sampleRate,
      type: _FilterType.highPass,
    );
  }

  factory _BiquadFilter.lowPass(double cutoffHz, int sampleRate) {
    return _BiquadFilter._design(
      f0: cutoffHz.clamp(1.0, sampleRate / 2 - 1),
      sampleRate: sampleRate,
      type: _FilterType.lowPass,
    );
  }

  static const double butterworthQ = 0.7071067811865476;

  factory _BiquadFilter._design({
    required double f0,
    required int sampleRate,
    required _FilterType type,
  }) {
    final fs = sampleRate.toDouble();
    final w0 = 2 * pi * f0 / fs;
    final cosW0 = cos(w0);
    final sinW0 = sin(w0);
    final alpha = sinW0 / (2 * butterworthQ);

    double b0, b1, b2, a0, a1, a2;
    switch (type) {
      case _FilterType.lowPass:
        b0 = (1 - cosW0) / 2;
        b1 = 1 - cosW0;
        b2 = (1 - cosW0) / 2;
        break;
      case _FilterType.highPass:
        b0 = (1 + cosW0) / 2;
        b1 = -(1 + cosW0);
        b2 = (1 + cosW0) / 2;
        break;
    }
    a0 = 1 + alpha;
    a1 = -2 * cosW0;
    a2 = 1 - alpha;

    return _BiquadFilter._(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }

  /// Direct form II transposed over the whole buffer.
  List<double> process(List<double> input) {
    final output = List<double>.filled(input.length, 0);
    for (var i = 0; i < input.length; i++) {
      final x = input[i];
      final y = b0 * x + _x1;
      _x1 = b1 * x - a1 * y + _x2;
      _x2 = b2 * x - a2 * y;
      output[i] = y;
    }
    return output;
  }
}

enum _FilterType { highPass, lowPass }

/// Tracks a noise floor with a slow RMS floor follower and applies a smooth
/// downward expander between breaths so ambient roar drops out but real
/// breath bursts pass through untouched.
class AdaptiveNoiseGate {
  final int sampleRate;
  final double openFactor;
  final double closedGain;

  static const int blockSize = 512;
  static const double gateTimeConstant = 0.03;

  AdaptiveNoiseGate({
    required this.sampleRate,
    required this.openFactor,
    required this.closedGain,
  });

  List<double> process(List<double> input) {
    if (input.isEmpty) {
      return input;
    }

    final perBlock = 1 / exp(
      -blockSize / (gateTimeConstant * sampleRate),
    );
    final blockCount = (input.length / blockSize).ceil();

    // Pass 1: measure every block's RMS.
    final blockRms = List<double>.filled(blockCount, 0);
    for (var b = 0; b < blockCount; b++) {
      blockRms[b] = _blockRms(input, b * blockSize);
    }

    // Estimate the ambient floor as a slow-tracking low percentile.
    var floor = blockRms.first;
    for (final rms in blockRms) {
      if (rms < floor) {
        floor = floor * (1 - 0.02) + rms * 0.02;
      } else {
        floor = floor * 0.999 + rms * 0.001;
      }
    }
    final threshold = floor * openFactor;

    // Per-block gain with smooth transitions so the gate never clicks.
    final gains = List<double>.filled(blockCount, 1.0);
    var current = closedGain;
    for (var b = 0; b < blockCount; b++) {
      final target = blockRms[b] > threshold ? 1.0 : closedGain;
      current = current + (target - current) / perBlock;
      gains[b] = current;
    }

    final output = List<double>.filled(input.length, 0);
    for (var i = 0; i < input.length; i++) {
      output[i] = input[i] * gains[min(i ~/ blockSize, blockCount - 1)];
    }
    return output;
  }

  double _blockRms(List<double> input, int start) {
    var sum = 0.0;
    final end = min(start + blockSize, input.length);
    for (var i = start; i < end; i++) {
      sum += input[i] * input[i];
    }
    final count = end - start;
    return count == 0 ? 0.0 : sqrt(sum / count);
  }
}

/// Raw 16-bit PCM WAV encoder/decoder sized exactly for this pipeline's needs.
class WavPcm16 {
  WavPcm16._();

  static const int bytesPerSample = 2;

  static ({List<double> samples, int sampleRate, int numChannels}) decode(
    Uint8List bytes,
  ) {
    if (bytes.length < 44) {
      return (samples: <double>[], sampleRate: 44100, numChannels: 1);
    }

    final view = ByteData.sublistView(bytes);
    if (_ascii(bytes, 0, 4) != 'RIFF' || _ascii(bytes, 8, 12) != 'WAVE') {
      return (samples: <double>[], sampleRate: 44100, numChannels: 1);
    }

    var offset = 12;
    int sampleRate = 44100;
    int numChannels = 1;
    int bitsPerSample = 16;
    int? dataOffset;
    int? dataLength;

    while (offset + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, offset, offset + 4);
      final chunkSize = view.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (chunkId == 'fmt ') {
        numChannels = view.getUint16(body + 2, Endian.little);
        sampleRate = view.getUint32(body + 4, Endian.little);
        bitsPerSample = view.getUint16(body + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = body;
        dataLength = min(chunkSize, bytes.length - body);
        break;
      }
      offset = body + chunkSize + (chunkSize & 1);
    }

    if (dataOffset == null ||
        bitsPerSample != 16 ||
        numChannels < 1 ||
        sampleRate < 1) {
      return (samples: <double>[], sampleRate: sampleRate, numChannels: 1);
    }

    final bytesPerFrame = numChannels * bytesPerSample;
    final frameCount = dataLength! ~/ bytesPerFrame;
    final samples = List<double>.filled(frameCount * numChannels, 0);
    for (var i = 0; i < samples.length; i++) {
      var value = view.getInt16(dataOffset + i * 2, Endian.little);
      samples[i] = value / 32768.0;
    }

    return (samples: samples, sampleRate: sampleRate, numChannels: numChannels);
  }

  static int bytesPerFrame(int bytesPerSample, int numChannels) =>
      bytesPerSample * numChannels;
  static Uint8List encode(
    List<double> samples,
    int sampleRate,
    int numChannels,
  ) {
    final dataLength = samples.length * bytesPerSample;
    final totalLength = 44 + dataLength;
    final bytes = Uint8List(totalLength);
    final view = ByteData.sublistView(bytes);

    _writeAscii(bytes, 0, 4, 'RIFF');
    view.setUint32(4, totalLength - 8, Endian.little);
    _writeAscii(bytes, 8, 12, 'WAVE');

    _writeAscii(bytes, 12, 16, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little); // PCM
    view.setUint16(22, numChannels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, sampleRate * numChannels * bytesPerSample, Endian.little);
    view.setUint16(32, numChannels * bytesPerSample, Endian.little);
    view.setUint16(34, 16, Endian.little);

    _writeAscii(bytes, 36, 40, 'data');
    view.setUint32(40, dataLength, Endian.little);

    for (var i = 0; i < samples.length; i++) {
      final clamped = (samples[i] * 32768.0).round().clamp(-32768, 32767);
      view.setInt16(44 + i * 2, clamped, Endian.little);
    }
    return bytes;
  }

  static String _ascii(Uint8List bytes, int start, int end) {
    return String.fromCharCodes(bytes.sublist(start, end));
  }

  static void _writeAscii(Uint8List bytes, int start, int end, String value) {
    for (var i = start; i < end; i++) {
      bytes[i] = value.codeUnitAt(i - start);
    }
  }
}
