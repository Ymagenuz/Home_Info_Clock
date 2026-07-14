import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project tree contains no Markdown documentation', () {
    const skippedDirectoryNames = <String>{
      '.dart_tool',
      '.git',
      '.gradle',
      '.pub-cache',
      'build',
    };
    final markdownPaths = <String>[];
    final pendingDirectories = <Directory>[Directory.current];

    while (pendingDirectories.isNotEmpty) {
      final directory = pendingDirectories.removeLast();
      for (final entity in directory.listSync(followLinks: false)) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!skippedDirectoryNames.contains(name)) {
            pendingDirectories.add(entity);
          }
        } else if (entity is File &&
            entity.path.toLowerCase().endsWith('.md')) {
          markdownPaths.add(entity.path);
        }
      }
    }

    markdownPaths.sort();
    expect(markdownPaths, isEmpty);
  });

  test('retired project artifacts stay absent', () {
    const retiredPaths = <String>[
      'clock.html',
      'legacy',
      'web',
      'lib/services/qweather_weather_source.dart',
      'lib/widgets/metric_cell.dart',
      'test/services/qweather_weather_source_test.dart',
    ];

    for (final path in retiredPaths) {
      expect(
        FileSystemEntity.typeSync(path),
        FileSystemEntityType.notFound,
        reason: path,
      );
    }

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('cryptography:')));
    expect(pubspec, isNot(contains('wakelock_plus:')));

    final config = File('lib/models/app_config.dart').readAsStringSync();
    expect(config, isNot(contains('qweather')));
    expect(config, isNot(contains('QWEATHER_')));
  });
}
