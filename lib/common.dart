import 'dart:io';

final desktopPlatform =
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;
final mobilePlatform = Platform.isAndroid || Platform.isIOS;

final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
bool validEmail(String email) {
  return emailRegExp.hasMatch(email);
}

abstract class Downloader {
  /// Downloads a file from the given URL to the given destination.
  ///
  /// if the file already exists, it will be overwritten.
  Future<void> download(String url, String dest);

  Future<void> downloadMulti(List<String> urls, String dest);
}
