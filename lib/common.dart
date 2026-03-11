import 'dart:io';

final desktopPlatform =
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;
final mobilePlatform = Platform.isAndroid || Platform.isIOS;
final applePlatform = Platform.isMacOS || Platform.isIOS;

final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
bool validEmail(String email) {
  return emailRegExp.hasMatch(email);
}
