// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get yes => '是的';

  @override
  String get no => '不';

  @override
  String hasNewerVersionDialog(String version) {
    return '有新版本$version可用，是否更新？';
  }

  @override
  String newVersionDownloadedDialog(String version) {
    return '新版本$version已下载，是否安装？';
  }

  @override
  String get skipThisVersion => '跳过此版本';

  @override
  String get install => '安装';

  @override
  String installFailed(String reason) {
    return '安装失败: $reason';
  }

  @override
  String get userConsend => '一旦登录成功，您的邮箱将存储在我们的服务器，直到您删除账户为止。这是为了提供账户登录功能所必需的个人信息。我们不会与任何第三方分享您的邮箱。您是否允许我们存储您的邮箱？';

  @override
  String get disagree => '不同意';

  @override
  String get email => '邮箱';

  @override
  String get okay => '好的';

  @override
  String get login => '登录';

  @override
  String get emailLogin => '邮箱登录';

  @override
  String get google => '谷歌';

  @override
  String get apple => '苹果';

  @override
  String get microsoft => '微软';

  @override
  String get pleaseUseAnotherEmail => '不支持该邮箱，请使用其他邮箱';

  @override
  String get verificationCode => '验证码';

  @override
  String get send => '发送';

  @override
  String get password => '密码';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get usePassword => '使用密码登录';

  @override
  String get useOtp => '使用验证码登录';
}
