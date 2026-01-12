import 'dart:io';

Future<String> arch() async {
  if (Platform.isLinux || Platform.isMacOS) {
    final result = await Process.run('uname', ['-m']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
  } else if (Platform.isWindows) {
    return Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'unknown';
  }
  return 'unknown';
}
