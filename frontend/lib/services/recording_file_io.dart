import 'dart:io';
import 'dart:typed_data';

Future<String> createRecordingPath() async {
  final tempDirectory = Directory.systemTemp;
  if (!await tempDirectory.exists()) {
    await tempDirectory.create(recursive: true);
  }

  return '${tempDirectory.path}${Platform.pathSeparator}'
      'kalavistar_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
}

Future<Uint8List?> readRecordedAudio(String path) async {
  if (path.trim().isEmpty) return null;

  final file = File(path);
  try {
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  } finally {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Cleanup is best-effort; the audio has already been read or failed.
    }
  }
}
