import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_health_monitor/components/noise_reduction.dart';
import 'package:smart_health_monitor/components/stetho_audio.dart';

/// Fake lung sound: amplitude-modulated 300 Hz tone bursting a few times,
/// 6 % leakage between bursts instead of silence.
List<double> breathSignal(int sampleRate, double seconds) {
  final rnd = Random(7);
  final samples = <double>[];
  final total = (sampleRate * seconds).toInt();
  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    final burst = sin(2 * pi * t / 0.4) > 0.55 ? 1.0 : 0.06;
    samples.add(
      0.5 * burst * sin(2 * pi * 300 * t) + 0.01 * (rnd.nextDouble() - 0.5),
    );
  }
  return samples;
}

/// Convention floor: brown rumble + 120 Hz hum + 7 kHz hiss, always on.
List<double> crowdNoise(int sampleRate, double seconds, {int seed = 3}) {
  final rnd = Random(seed);
  final total = (sampleRate * seconds).toInt();
  final samples = List<double>.filled(total, 0);
  var last = 0.0;
  for (var i = 0; i < total; i++) {
    last = (last + 0.02 * (rnd.nextDouble() - 0.5)).clamp(-1.0, 1.0);
    samples[i] =
        0.35 * last + 0.25 * sin(2 * pi * 120 * i / sampleRate) + 0.15 * sin(2 * pi * 7000 * i / sampleRate);
  }
  return samples;
}

double avgAbs(List<double> s, int start, int end) {
  final clampedEnd = (end > s.length) ? s.length : end;
  final count = (clampedEnd - start).clamp(1, 1 << 30);
  var sum = 0.0;
  for (var i = start; i < clampedEnd; i++) {
    sum += s[i].abs();
  }
  return sum / count;
}

/// Goertzel-style single-frequency energy over the whole the sample buffer.
double bandEnergy(List<double> s, int sampleRate, int fromHz, int toHz) {
  var energy = 0.0;
  const step = 25;
  for (var f = fromHz; f <= toHz; f += step) {
    final angular = 2 * pi * f / sampleRate;
    var re = 0.0;
    var im = 0.0;
    for (var i = 0; i < s.length; i += 4) {
      re += s[i] * cos(angular * i);
      im -= s[i] * sin(angular * i);
    }
    energy += re * re + im * im;
  }
  return energy;
}

void main() {
  test('noise gate attenuates gaps between breath bursts', () {
    const rate = 44100;
    final clean = breathSignal(rate, 1.0);
    final gated = AdaptiveNoiseGate(
      sampleRate: rate,
      openFactor: StethoAudio.gateOpenFactor,
      closedGain: StethoAudio.gateClosedGain,
    ).process(List<double>.of(clean));

    // Gap window t∈(0.20, 0.35) is between bursts; burst window t∈(0.47,0.55).
    final gapIn = avgAbs(clean, (rate * 0.20).toInt(), (rate * 0.35).toInt());
    final gapOut =
        avgAbs(gated, (rate * 0.20).toInt(), (rate * 0.35).toInt());
    final burstIn =
        avgAbs(clean, (rate * 0.47).toInt(), (rate * 0.55).toInt());
    final burstOut =
        avgAbs(gated, (rate * 0.47).toInt(), (rate * 0.55).toInt());

    expect(gapOut, lessThan(gapIn * 0.5), reason: 'gaps must be attenuated');
    expect(burstOut, greaterThan(burstIn * 0.9), reason: 'bursts must survive');
  });

  test('enhance removes rumble and hiss from convention noise', () {
    const rate = 44100;
    final noisy = crowdNoise(rate, 1.0);
    final cleaned = StethoAudio.enhance(List<double>.of(noisy), rate);

    final hissIn = bandEnergy(noisy, rate, 6500, 8000);
    final hissOut = bandEnergy(cleaned, rate, 6500, 8000);
    expect(hissOut, lessThan(hissIn * 0.5), reason: 'hiss must be cut');

    final rumbleIn = bandEnergy(noisy, rate, 10, 45);
    final rumbleOut = bandEnergy(cleaned, rate, 10, 45);
    expect(rumbleOut, lessThan(rumbleIn * 0.2), reason: 'rumble must be cut');
  });

  test('enhance preserves the breath band', () {
    const rate = 44100;
    final clean = breathSignal(rate, 1.0);
    final processed = StethoAudio.enhance(List<double>.of(clean), rate);

    final breathIn = bandEnergy(clean, rate, 250, 350);
    final breathOut = bandEnergy(processed, rate, 250, 350);
    expect(breathOut, greaterThan(breathIn * 0.5));
  });

  test('wav roundtrip preserves samples', () {
    const rate = 16000;
    final samples = [0.0, 0.25, -0.5, 0.75, -1.0, 1.0, 0.5, -0.25];
    final encoded = WavPcm16.encode(samples, rate, 1);
    final decoded = WavPcm16.decode(Uint8List.fromList(encoded));

    expect(decoded.sampleRate, rate);
    expect(decoded.numChannels, 1);
    expect(decoded.samples.length, samples.length);
    for (var i = 0; i < samples.length; i++) {
      expect(decoded.samples[i], closeTo(samples[i], 0.001));
    }
  });

  test('cleanFile reports failure for missing file / disabled pipeline', () async {
    DiagnosticSettings.noiseReductionEnabled = false;
    expect(await StethoAudio.cleanFile('/nonexistent/take.wav'), isFalse);
    DiagnosticSettings.noiseReductionEnabled = true;
  });
}
