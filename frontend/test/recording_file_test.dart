import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/services/recording_file.dart';

void main() {
  test('creates a WAV path and reads the recorded bytes', () async {
    final path = await createRecordingPath();
    final file = File(path);
    final expectedBytes = List<int>.generate(256, (index) => index);

    await file.writeAsBytes(expectedBytes);

    final audioBytes = await readRecordedAudio(path);

    expect(path, endsWith('.wav'));
    expect(audioBytes, orderedEquals(expectedBytes));
    expect(await file.exists(), isFalse);
  });
}
