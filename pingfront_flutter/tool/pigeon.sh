#!/usr/bin/env bash
# Regenerates the Dart, Swift and Kotlin bridge code from pigeons/messages.dart.
set -euo pipefail
cd "$(dirname "$0")/.."
dart run pigeon --input pigeons/messages.dart
dart format lib/src/messages.g.dart
