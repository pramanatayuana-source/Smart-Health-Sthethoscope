import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Text file types that could carry brand copy.
const _textExtensions = <String>{
  '.arb',
  '.cc',
  '.cmake',
  '.dart',
  '.gradle',
  '.h',
  '.html',
  '.java',
  '.json',
  '.kt',
  '.kts',
  '.m',
  '.md',
  '.plist',
  '.properties',
  '.rc',
  '.swift',
  '.txt',
  '.xcconfig',
  '.xml',
  '.yaml',
  '.yml',
};

/// Directories that are generated, vendored or out of scope.
const _skipDirs = <String>{
  '.dart_tool',
  '.git',
  '.gradle',
  '.hermes',
  '.idea',
  '.vscode',
  'build',
  'ephemeral',
};

void main() {
  test('retired RESPIRA brand token appears in no source file', () {
    // The \b keeps this from matching the ordinary word "respiratory".
    final brand =
        RegExp(r'\bRESPIRA\b|R\.E\.S\.P\.I\.R\.A', caseSensitive: false);
    final offenders = <String>[];

    for (final entity in Directory.current.listSync(recursive: true)) {
      if (entity is! File) continue;

      final segments = entity.path.split(Platform.pathSeparator);
      if (segments.any(_skipDirs.contains)) continue;
      // This test necessarily contains the token it hunts for.
      if (entity.path.endsWith('branding_test.dart')) continue;
      if (!_textExtensions.contains(_extensionOf(entity.path))) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (brand.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Old brand text still present:\n${offenders.join('\n')}',
    );
  });
}

String _extensionOf(String path) {
  final dot = path.lastIndexOf('.');
  return dot == -1 ? '' : path.substring(dot).toLowerCase();
}
