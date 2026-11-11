import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_flutter/src/codec.dart';

void main() {
  test('configure carries this plugin\'s version for PF-Wrapper', () {
    final request = encodeConfigure(
      'pk_test_abcdefghijklmnopqrstuvvd',
      const PingFrontOptions(),
      handlesOffers: false,
      handlesLinks: false,
    );
    expect(request.wrapperVersion, pluginVersion);
  });

  test('the plugin version follows pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final version = pubspec
        .firstWhere((l) => l.startsWith('version:'))
        .split(':')[1]
        .trim();
    expect(pluginVersion, version);
  });
}
