// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String hasNewerVersionDialog(String version) {
    return 'New version $version available, update it?';
  }

  @override
  String newVersionDownloadedDialog(String version) {
    return 'New version $version downloaded, install it?';
  }

  @override
  String get skipThisVersion => 'Skip this version';

  @override
  String get install => 'Install';

  @override
  String installFailed(String reason) {
    return 'Failed to install update, reason: $reason';
  }

  @override
  String get userConsend => 'Once you login, your email will be stored in our server until you delete your account. This is neccessary for providing account login. We do not share your email with any third party. Do you allow us to store your email?';

  @override
  String get disagree => 'Disagree';

  @override
  String get email => 'Email';

  @override
  String get okay => 'Okay';

  @override
  String get login => 'Login';

  @override
  String get emailLogin => 'Login by Email';

  @override
  String get google => 'Google';

  @override
  String get apple => 'Apple';

  @override
  String get microsoft => 'Microsoft';

  @override
  String get pleaseUseAnotherEmail => 'Unsupported email, please use another email';

  @override
  String get verificationCode => 'Verification Code';

  @override
  String get send => 'Send';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Password required';

  @override
  String get usePassword => 'Use password';

  @override
  String get useOtp => 'Use OTP';
}
