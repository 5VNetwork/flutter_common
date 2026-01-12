import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @newVersionDownloadedDialog.
  ///
  /// In en, this message translates to:
  /// **'New version {version} downloaded, install it?'**
  String newVersionDownloadedDialog(String version);

  /// No description provided for @skipThisVersion.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get skipThisVersion;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @installFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to install update, reason: {reason}'**
  String installFailed(String reason);

  /// No description provided for @userConsend.
  ///
  /// In en, this message translates to:
  /// **'Once you login, your email will be stored in our server until you delete your account. This is neccessary for providing account login. We do not share your email with any third party. Do you allow us to store your email?'**
  String get userConsend;

  /// No description provided for @disagree.
  ///
  /// In en, this message translates to:
  /// **'Disagree'**
  String get disagree;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @okay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get okay;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @emailLogin.
  ///
  /// In en, this message translates to:
  /// **'Login by Email'**
  String get emailLogin;

  /// No description provided for @google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  /// No description provided for @apple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get apple;

  /// No description provided for @microsoft.
  ///
  /// In en, this message translates to:
  /// **'Microsoft'**
  String get microsoft;

  /// No description provided for @pleaseUseAnotherEmail.
  ///
  /// In en, this message translates to:
  /// **'Unsupported email, please use another email'**
  String get pleaseUseAnotherEmail;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCode;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @country_AF.
  ///
  /// In en, this message translates to:
  /// **'Afghanistan'**
  String get country_AF;

  /// No description provided for @country_AX.
  ///
  /// In en, this message translates to:
  /// **'Aland Islands'**
  String get country_AX;

  /// No description provided for @country_AL.
  ///
  /// In en, this message translates to:
  /// **'Albania'**
  String get country_AL;

  /// No description provided for @country_DZ.
  ///
  /// In en, this message translates to:
  /// **'Algeria'**
  String get country_DZ;

  /// No description provided for @country_AS.
  ///
  /// In en, this message translates to:
  /// **'American Samoa'**
  String get country_AS;

  /// No description provided for @country_AD.
  ///
  /// In en, this message translates to:
  /// **'Andorra'**
  String get country_AD;

  /// No description provided for @country_AO.
  ///
  /// In en, this message translates to:
  /// **'Angola'**
  String get country_AO;

  /// No description provided for @country_AI.
  ///
  /// In en, this message translates to:
  /// **'Anguilla'**
  String get country_AI;

  /// No description provided for @country_AQ.
  ///
  /// In en, this message translates to:
  /// **'Antarctica'**
  String get country_AQ;

  /// No description provided for @country_AG.
  ///
  /// In en, this message translates to:
  /// **'Antigua and Barbuda'**
  String get country_AG;

  /// No description provided for @country_AR.
  ///
  /// In en, this message translates to:
  /// **'Argentina'**
  String get country_AR;

  /// No description provided for @country_AM.
  ///
  /// In en, this message translates to:
  /// **'Armenia'**
  String get country_AM;

  /// No description provided for @country_AW.
  ///
  /// In en, this message translates to:
  /// **'Aruba'**
  String get country_AW;

  /// No description provided for @country_AU.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get country_AU;

  /// No description provided for @country_AT.
  ///
  /// In en, this message translates to:
  /// **'Austria'**
  String get country_AT;

  /// No description provided for @country_AZ.
  ///
  /// In en, this message translates to:
  /// **'Azerbaijan'**
  String get country_AZ;

  /// No description provided for @country_BH.
  ///
  /// In en, this message translates to:
  /// **'Bahrain'**
  String get country_BH;

  /// No description provided for @country_BD.
  ///
  /// In en, this message translates to:
  /// **'Bangladesh'**
  String get country_BD;

  /// No description provided for @country_BB.
  ///
  /// In en, this message translates to:
  /// **'Barbados'**
  String get country_BB;

  /// No description provided for @country_BY.
  ///
  /// In en, this message translates to:
  /// **'Belarus'**
  String get country_BY;

  /// No description provided for @country_BE.
  ///
  /// In en, this message translates to:
  /// **'Belgium'**
  String get country_BE;

  /// No description provided for @country_BZ.
  ///
  /// In en, this message translates to:
  /// **'Belize'**
  String get country_BZ;

  /// No description provided for @country_BJ.
  ///
  /// In en, this message translates to:
  /// **'Benin'**
  String get country_BJ;

  /// No description provided for @country_BM.
  ///
  /// In en, this message translates to:
  /// **'Bermuda'**
  String get country_BM;

  /// No description provided for @country_BT.
  ///
  /// In en, this message translates to:
  /// **'Bhutan'**
  String get country_BT;

  /// No description provided for @country_BO.
  ///
  /// In en, this message translates to:
  /// **'Bolivia'**
  String get country_BO;

  /// No description provided for @country_BQ.
  ///
  /// In en, this message translates to:
  /// **'Bonaire, Sint Eustatius and Saba'**
  String get country_BQ;

  /// No description provided for @country_BA.
  ///
  /// In en, this message translates to:
  /// **'Bosnia and Herzegovina'**
  String get country_BA;

  /// No description provided for @country_BW.
  ///
  /// In en, this message translates to:
  /// **'Botswana'**
  String get country_BW;

  /// No description provided for @country_BV.
  ///
  /// In en, this message translates to:
  /// **'Bouvet Island'**
  String get country_BV;

  /// No description provided for @country_BR.
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get country_BR;

  /// No description provided for @country_IO.
  ///
  /// In en, this message translates to:
  /// **'British Indian Ocean Territory'**
  String get country_IO;

  /// No description provided for @country_BN.
  ///
  /// In en, this message translates to:
  /// **'Brunei'**
  String get country_BN;

  /// No description provided for @country_BG.
  ///
  /// In en, this message translates to:
  /// **'Bulgaria'**
  String get country_BG;

  /// No description provided for @country_BF.
  ///
  /// In en, this message translates to:
  /// **'Burkina Faso'**
  String get country_BF;

  /// No description provided for @country_BI.
  ///
  /// In en, this message translates to:
  /// **'Burundi'**
  String get country_BI;

  /// No description provided for @country_KH.
  ///
  /// In en, this message translates to:
  /// **'Cambodia'**
  String get country_KH;

  /// No description provided for @country_CM.
  ///
  /// In en, this message translates to:
  /// **'Cameroon'**
  String get country_CM;

  /// No description provided for @country_CA.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get country_CA;

  /// No description provided for @country_CV.
  ///
  /// In en, this message translates to:
  /// **'Cape Verde'**
  String get country_CV;

  /// No description provided for @country_KY.
  ///
  /// In en, this message translates to:
  /// **'Cayman Islands'**
  String get country_KY;

  /// No description provided for @country_CF.
  ///
  /// In en, this message translates to:
  /// **'Central African Republic'**
  String get country_CF;

  /// No description provided for @country_TD.
  ///
  /// In en, this message translates to:
  /// **'Chad'**
  String get country_TD;

  /// No description provided for @country_CL.
  ///
  /// In en, this message translates to:
  /// **'Chile'**
  String get country_CL;

  /// No description provided for @country_CX.
  ///
  /// In en, this message translates to:
  /// **'Christmas Island'**
  String get country_CX;

  /// No description provided for @country_CC.
  ///
  /// In en, this message translates to:
  /// **'Cocos (Keeling) Islands'**
  String get country_CC;

  /// No description provided for @country_CO.
  ///
  /// In en, this message translates to:
  /// **'Colombia'**
  String get country_CO;

  /// No description provided for @country_KM.
  ///
  /// In en, this message translates to:
  /// **'Comoros'**
  String get country_KM;

  /// No description provided for @country_CG.
  ///
  /// In en, this message translates to:
  /// **'Congo'**
  String get country_CG;

  /// No description provided for @country_CK.
  ///
  /// In en, this message translates to:
  /// **'Cook Islands'**
  String get country_CK;

  /// No description provided for @country_CR.
  ///
  /// In en, this message translates to:
  /// **'Costa Rica'**
  String get country_CR;

  /// No description provided for @country_CI.
  ///
  /// In en, this message translates to:
  /// **'Cote D\'Ivoire (Ivory Coast)'**
  String get country_CI;

  /// No description provided for @country_HR.
  ///
  /// In en, this message translates to:
  /// **'Croatia'**
  String get country_HR;

  /// No description provided for @country_CU.
  ///
  /// In en, this message translates to:
  /// **'Cuba'**
  String get country_CU;

  /// No description provided for @country_CW.
  ///
  /// In en, this message translates to:
  /// **'Curaçao'**
  String get country_CW;

  /// No description provided for @country_CY.
  ///
  /// In en, this message translates to:
  /// **'Cyprus'**
  String get country_CY;

  /// No description provided for @country_CZ.
  ///
  /// In en, this message translates to:
  /// **'Czech Republic'**
  String get country_CZ;

  /// No description provided for @country_CD.
  ///
  /// In en, this message translates to:
  /// **'Democratic Republic of the Congo'**
  String get country_CD;

  /// No description provided for @country_DK.
  ///
  /// In en, this message translates to:
  /// **'Denmark'**
  String get country_DK;

  /// No description provided for @country_DJ.
  ///
  /// In en, this message translates to:
  /// **'Djibouti'**
  String get country_DJ;

  /// No description provided for @country_DM.
  ///
  /// In en, this message translates to:
  /// **'Dominica'**
  String get country_DM;

  /// No description provided for @country_DO.
  ///
  /// In en, this message translates to:
  /// **'Dominican Republic'**
  String get country_DO;

  /// No description provided for @country_EC.
  ///
  /// In en, this message translates to:
  /// **'Ecuador'**
  String get country_EC;

  /// No description provided for @country_EG.
  ///
  /// In en, this message translates to:
  /// **'Egypt'**
  String get country_EG;

  /// No description provided for @country_SV.
  ///
  /// In en, this message translates to:
  /// **'El Salvador'**
  String get country_SV;

  /// No description provided for @country_GQ.
  ///
  /// In en, this message translates to:
  /// **'Equatorial Guinea'**
  String get country_GQ;

  /// No description provided for @country_ER.
  ///
  /// In en, this message translates to:
  /// **'Eritrea'**
  String get country_ER;

  /// No description provided for @country_EE.
  ///
  /// In en, this message translates to:
  /// **'Estonia'**
  String get country_EE;

  /// No description provided for @country_SZ.
  ///
  /// In en, this message translates to:
  /// **'Eswatini'**
  String get country_SZ;

  /// No description provided for @country_ET.
  ///
  /// In en, this message translates to:
  /// **'Ethiopia'**
  String get country_ET;

  /// No description provided for @country_FK.
  ///
  /// In en, this message translates to:
  /// **'Falkland Islands'**
  String get country_FK;

  /// No description provided for @country_FO.
  ///
  /// In en, this message translates to:
  /// **'Faroe Islands'**
  String get country_FO;

  /// No description provided for @country_FJ.
  ///
  /// In en, this message translates to:
  /// **'Fiji Islands'**
  String get country_FJ;

  /// No description provided for @country_FI.
  ///
  /// In en, this message translates to:
  /// **'Finland'**
  String get country_FI;

  /// No description provided for @country_FR.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get country_FR;

  /// No description provided for @country_GF.
  ///
  /// In en, this message translates to:
  /// **'French Guiana'**
  String get country_GF;

  /// No description provided for @country_PF.
  ///
  /// In en, this message translates to:
  /// **'French Polynesia'**
  String get country_PF;

  /// No description provided for @country_TF.
  ///
  /// In en, this message translates to:
  /// **'French Southern Territories'**
  String get country_TF;

  /// No description provided for @country_GA.
  ///
  /// In en, this message translates to:
  /// **'Gabon'**
  String get country_GA;

  /// No description provided for @country_GE.
  ///
  /// In en, this message translates to:
  /// **'Georgia'**
  String get country_GE;

  /// No description provided for @country_DE.
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get country_DE;

  /// No description provided for @country_GH.
  ///
  /// In en, this message translates to:
  /// **'Ghana'**
  String get country_GH;

  /// No description provided for @country_GI.
  ///
  /// In en, this message translates to:
  /// **'Gibraltar'**
  String get country_GI;

  /// No description provided for @country_GR.
  ///
  /// In en, this message translates to:
  /// **'Greece'**
  String get country_GR;

  /// No description provided for @country_GL.
  ///
  /// In en, this message translates to:
  /// **'Greenland'**
  String get country_GL;

  /// No description provided for @country_GD.
  ///
  /// In en, this message translates to:
  /// **'Grenada'**
  String get country_GD;

  /// No description provided for @country_GP.
  ///
  /// In en, this message translates to:
  /// **'Guadeloupe'**
  String get country_GP;

  /// No description provided for @country_GU.
  ///
  /// In en, this message translates to:
  /// **'Guam'**
  String get country_GU;

  /// No description provided for @country_GT.
  ///
  /// In en, this message translates to:
  /// **'Guatemala'**
  String get country_GT;

  /// No description provided for @country_GG.
  ///
  /// In en, this message translates to:
  /// **'Guernsey and Alderney'**
  String get country_GG;

  /// No description provided for @country_GN.
  ///
  /// In en, this message translates to:
  /// **'Guinea'**
  String get country_GN;

  /// No description provided for @country_GW.
  ///
  /// In en, this message translates to:
  /// **'Guinea-Bissau'**
  String get country_GW;

  /// No description provided for @country_GY.
  ///
  /// In en, this message translates to:
  /// **'Guyana'**
  String get country_GY;

  /// No description provided for @country_HT.
  ///
  /// In en, this message translates to:
  /// **'Haiti'**
  String get country_HT;

  /// No description provided for @country_HM.
  ///
  /// In en, this message translates to:
  /// **'Heard Island and McDonald Islands'**
  String get country_HM;

  /// No description provided for @country_HN.
  ///
  /// In en, this message translates to:
  /// **'Honduras'**
  String get country_HN;

  /// No description provided for @country_HK.
  ///
  /// In en, this message translates to:
  /// **'Hong Kong S.A.R.'**
  String get country_HK;

  /// No description provided for @country_HU.
  ///
  /// In en, this message translates to:
  /// **'Hungary'**
  String get country_HU;

  /// No description provided for @country_IS.
  ///
  /// In en, this message translates to:
  /// **'Iceland'**
  String get country_IS;

  /// No description provided for @country_IN.
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get country_IN;

  /// No description provided for @country_ID.
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get country_ID;

  /// No description provided for @country_IR.
  ///
  /// In en, this message translates to:
  /// **'Iran'**
  String get country_IR;

  /// No description provided for @country_IQ.
  ///
  /// In en, this message translates to:
  /// **'Iraq'**
  String get country_IQ;

  /// No description provided for @country_IE.
  ///
  /// In en, this message translates to:
  /// **'Ireland'**
  String get country_IE;

  /// No description provided for @country_IL.
  ///
  /// In en, this message translates to:
  /// **'Israel'**
  String get country_IL;

  /// No description provided for @country_IT.
  ///
  /// In en, this message translates to:
  /// **'Italy'**
  String get country_IT;

  /// No description provided for @country_JM.
  ///
  /// In en, this message translates to:
  /// **'Jamaica'**
  String get country_JM;

  /// No description provided for @country_JP.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get country_JP;

  /// No description provided for @country_JE.
  ///
  /// In en, this message translates to:
  /// **'Jersey'**
  String get country_JE;

  /// No description provided for @country_JO.
  ///
  /// In en, this message translates to:
  /// **'Jordan'**
  String get country_JO;

  /// No description provided for @country_KZ.
  ///
  /// In en, this message translates to:
  /// **'Kazakhstan'**
  String get country_KZ;

  /// No description provided for @country_KE.
  ///
  /// In en, this message translates to:
  /// **'Kenya'**
  String get country_KE;

  /// No description provided for @country_KI.
  ///
  /// In en, this message translates to:
  /// **'Kiribati'**
  String get country_KI;

  /// No description provided for @country_XK.
  ///
  /// In en, this message translates to:
  /// **'Kosovo'**
  String get country_XK;

  /// No description provided for @country_KW.
  ///
  /// In en, this message translates to:
  /// **'Kuwait'**
  String get country_KW;

  /// No description provided for @country_KG.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyzstan'**
  String get country_KG;

  /// No description provided for @country_LA.
  ///
  /// In en, this message translates to:
  /// **'Laos'**
  String get country_LA;

  /// No description provided for @country_LV.
  ///
  /// In en, this message translates to:
  /// **'Latvia'**
  String get country_LV;

  /// No description provided for @country_LB.
  ///
  /// In en, this message translates to:
  /// **'Lebanon'**
  String get country_LB;

  /// No description provided for @country_LS.
  ///
  /// In en, this message translates to:
  /// **'Lesotho'**
  String get country_LS;

  /// No description provided for @country_LR.
  ///
  /// In en, this message translates to:
  /// **'Liberia'**
  String get country_LR;

  /// No description provided for @country_LY.
  ///
  /// In en, this message translates to:
  /// **'Libya'**
  String get country_LY;

  /// No description provided for @country_LI.
  ///
  /// In en, this message translates to:
  /// **'Liechtenstein'**
  String get country_LI;

  /// No description provided for @country_LT.
  ///
  /// In en, this message translates to:
  /// **'Lithuania'**
  String get country_LT;

  /// No description provided for @country_LU.
  ///
  /// In en, this message translates to:
  /// **'Luxembourg'**
  String get country_LU;

  /// No description provided for @country_MO.
  ///
  /// In en, this message translates to:
  /// **'Macau S.A.R.'**
  String get country_MO;

  /// No description provided for @country_MG.
  ///
  /// In en, this message translates to:
  /// **'Madagascar'**
  String get country_MG;

  /// No description provided for @country_MW.
  ///
  /// In en, this message translates to:
  /// **'Malawi'**
  String get country_MW;

  /// No description provided for @country_MY.
  ///
  /// In en, this message translates to:
  /// **'Malaysia'**
  String get country_MY;

  /// No description provided for @country_MV.
  ///
  /// In en, this message translates to:
  /// **'Maldives'**
  String get country_MV;

  /// No description provided for @country_ML.
  ///
  /// In en, this message translates to:
  /// **'Mali'**
  String get country_ML;

  /// No description provided for @country_MT.
  ///
  /// In en, this message translates to:
  /// **'Malta'**
  String get country_MT;

  /// No description provided for @country_IM.
  ///
  /// In en, this message translates to:
  /// **'Man (Isle of)'**
  String get country_IM;

  /// No description provided for @country_MH.
  ///
  /// In en, this message translates to:
  /// **'Marshall Islands'**
  String get country_MH;

  /// No description provided for @country_MQ.
  ///
  /// In en, this message translates to:
  /// **'Martinique'**
  String get country_MQ;

  /// No description provided for @country_MR.
  ///
  /// In en, this message translates to:
  /// **'Mauritania'**
  String get country_MR;

  /// No description provided for @country_MU.
  ///
  /// In en, this message translates to:
  /// **'Mauritius'**
  String get country_MU;

  /// No description provided for @country_YT.
  ///
  /// In en, this message translates to:
  /// **'Mayotte'**
  String get country_YT;

  /// No description provided for @country_MX.
  ///
  /// In en, this message translates to:
  /// **'Mexico'**
  String get country_MX;

  /// No description provided for @country_FM.
  ///
  /// In en, this message translates to:
  /// **'Micronesia'**
  String get country_FM;

  /// No description provided for @country_MD.
  ///
  /// In en, this message translates to:
  /// **'Moldova'**
  String get country_MD;

  /// No description provided for @country_MC.
  ///
  /// In en, this message translates to:
  /// **'Monaco'**
  String get country_MC;

  /// No description provided for @country_MN.
  ///
  /// In en, this message translates to:
  /// **'Mongolia'**
  String get country_MN;

  /// No description provided for @country_ME.
  ///
  /// In en, this message translates to:
  /// **'Montenegro'**
  String get country_ME;

  /// No description provided for @country_MS.
  ///
  /// In en, this message translates to:
  /// **'Montserrat'**
  String get country_MS;

  /// No description provided for @country_MA.
  ///
  /// In en, this message translates to:
  /// **'Morocco'**
  String get country_MA;

  /// No description provided for @country_MZ.
  ///
  /// In en, this message translates to:
  /// **'Mozambique'**
  String get country_MZ;

  /// No description provided for @country_MM.
  ///
  /// In en, this message translates to:
  /// **'Myanmar'**
  String get country_MM;

  /// No description provided for @country_NA.
  ///
  /// In en, this message translates to:
  /// **'Namibia'**
  String get country_NA;

  /// No description provided for @country_NR.
  ///
  /// In en, this message translates to:
  /// **'Nauru'**
  String get country_NR;

  /// No description provided for @country_NP.
  ///
  /// In en, this message translates to:
  /// **'Nepal'**
  String get country_NP;

  /// No description provided for @country_NL.
  ///
  /// In en, this message translates to:
  /// **'Netherlands'**
  String get country_NL;

  /// No description provided for @country_NC.
  ///
  /// In en, this message translates to:
  /// **'New Caledonia'**
  String get country_NC;

  /// No description provided for @country_NZ.
  ///
  /// In en, this message translates to:
  /// **'New Zealand'**
  String get country_NZ;

  /// No description provided for @country_NI.
  ///
  /// In en, this message translates to:
  /// **'Nicaragua'**
  String get country_NI;

  /// No description provided for @country_NE.
  ///
  /// In en, this message translates to:
  /// **'Niger'**
  String get country_NE;

  /// No description provided for @country_NG.
  ///
  /// In en, this message translates to:
  /// **'Nigeria'**
  String get country_NG;

  /// No description provided for @country_NU.
  ///
  /// In en, this message translates to:
  /// **'Niue'**
  String get country_NU;

  /// No description provided for @country_NF.
  ///
  /// In en, this message translates to:
  /// **'Norfolk Island'**
  String get country_NF;

  /// No description provided for @country_KP.
  ///
  /// In en, this message translates to:
  /// **'North Korea'**
  String get country_KP;

  /// No description provided for @country_MK.
  ///
  /// In en, this message translates to:
  /// **'North Macedonia'**
  String get country_MK;

  /// No description provided for @country_MP.
  ///
  /// In en, this message translates to:
  /// **'Northern Mariana Islands'**
  String get country_MP;

  /// No description provided for @country_NO.
  ///
  /// In en, this message translates to:
  /// **'Norway'**
  String get country_NO;

  /// No description provided for @country_OM.
  ///
  /// In en, this message translates to:
  /// **'Oman'**
  String get country_OM;

  /// No description provided for @country_PK.
  ///
  /// In en, this message translates to:
  /// **'Pakistan'**
  String get country_PK;

  /// No description provided for @country_PW.
  ///
  /// In en, this message translates to:
  /// **'Palau'**
  String get country_PW;

  /// No description provided for @country_PS.
  ///
  /// In en, this message translates to:
  /// **'Palestinian Territory Occupied'**
  String get country_PS;

  /// No description provided for @country_PA.
  ///
  /// In en, this message translates to:
  /// **'Panama'**
  String get country_PA;

  /// No description provided for @country_PG.
  ///
  /// In en, this message translates to:
  /// **'Papua New Guinea'**
  String get country_PG;

  /// No description provided for @country_PY.
  ///
  /// In en, this message translates to:
  /// **'Paraguay'**
  String get country_PY;

  /// No description provided for @country_PE.
  ///
  /// In en, this message translates to:
  /// **'Peru'**
  String get country_PE;

  /// No description provided for @country_PH.
  ///
  /// In en, this message translates to:
  /// **'Philippines'**
  String get country_PH;

  /// No description provided for @country_PN.
  ///
  /// In en, this message translates to:
  /// **'Pitcairn Island'**
  String get country_PN;

  /// No description provided for @country_PL.
  ///
  /// In en, this message translates to:
  /// **'Poland'**
  String get country_PL;

  /// No description provided for @country_PT.
  ///
  /// In en, this message translates to:
  /// **'Portugal'**
  String get country_PT;

  /// No description provided for @country_PR.
  ///
  /// In en, this message translates to:
  /// **'Puerto Rico'**
  String get country_PR;

  /// No description provided for @country_QA.
  ///
  /// In en, this message translates to:
  /// **'Qatar'**
  String get country_QA;

  /// No description provided for @country_RE.
  ///
  /// In en, this message translates to:
  /// **'Reunion'**
  String get country_RE;

  /// No description provided for @country_RO.
  ///
  /// In en, this message translates to:
  /// **'Romania'**
  String get country_RO;

  /// No description provided for @country_RU.
  ///
  /// In en, this message translates to:
  /// **'Russia'**
  String get country_RU;

  /// No description provided for @country_RW.
  ///
  /// In en, this message translates to:
  /// **'Rwanda'**
  String get country_RW;

  /// No description provided for @country_SH.
  ///
  /// In en, this message translates to:
  /// **'Saint Helena'**
  String get country_SH;

  /// No description provided for @country_KN.
  ///
  /// In en, this message translates to:
  /// **'Saint Kitts and Nevis'**
  String get country_KN;

  /// No description provided for @country_LC.
  ///
  /// In en, this message translates to:
  /// **'Saint Lucia'**
  String get country_LC;

  /// No description provided for @country_PM.
  ///
  /// In en, this message translates to:
  /// **'Saint Pierre and Miquelon'**
  String get country_PM;

  /// No description provided for @country_VC.
  ///
  /// In en, this message translates to:
  /// **'Saint Vincent and the Grenadines'**
  String get country_VC;

  /// No description provided for @country_BL.
  ///
  /// In en, this message translates to:
  /// **'Saint-Barthelemy'**
  String get country_BL;

  /// No description provided for @country_MF.
  ///
  /// In en, this message translates to:
  /// **'Saint-Martin (French part)'**
  String get country_MF;

  /// No description provided for @country_WS.
  ///
  /// In en, this message translates to:
  /// **'Samoa'**
  String get country_WS;

  /// No description provided for @country_SM.
  ///
  /// In en, this message translates to:
  /// **'San Marino'**
  String get country_SM;

  /// No description provided for @country_ST.
  ///
  /// In en, this message translates to:
  /// **'Sao Tome and Principe'**
  String get country_ST;

  /// No description provided for @country_SA.
  ///
  /// In en, this message translates to:
  /// **'Saudi Arabia'**
  String get country_SA;

  /// No description provided for @country_SN.
  ///
  /// In en, this message translates to:
  /// **'Senegal'**
  String get country_SN;

  /// No description provided for @country_RS.
  ///
  /// In en, this message translates to:
  /// **'Serbia'**
  String get country_RS;

  /// No description provided for @country_SC.
  ///
  /// In en, this message translates to:
  /// **'Seychelles'**
  String get country_SC;

  /// No description provided for @country_SL.
  ///
  /// In en, this message translates to:
  /// **'Sierra Leone'**
  String get country_SL;

  /// No description provided for @country_SG.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get country_SG;

  /// No description provided for @country_SX.
  ///
  /// In en, this message translates to:
  /// **'Sint Maarten (Dutch part)'**
  String get country_SX;

  /// No description provided for @country_SK.
  ///
  /// In en, this message translates to:
  /// **'Slovakia'**
  String get country_SK;

  /// No description provided for @country_SI.
  ///
  /// In en, this message translates to:
  /// **'Slovenia'**
  String get country_SI;

  /// No description provided for @country_SB.
  ///
  /// In en, this message translates to:
  /// **'Solomon Islands'**
  String get country_SB;

  /// No description provided for @country_SO.
  ///
  /// In en, this message translates to:
  /// **'Somalia'**
  String get country_SO;

  /// No description provided for @country_ZA.
  ///
  /// In en, this message translates to:
  /// **'South Africa'**
  String get country_ZA;

  /// No description provided for @country_GS.
  ///
  /// In en, this message translates to:
  /// **'South Georgia'**
  String get country_GS;

  /// No description provided for @country_KR.
  ///
  /// In en, this message translates to:
  /// **'South Korea'**
  String get country_KR;

  /// No description provided for @country_SS.
  ///
  /// In en, this message translates to:
  /// **'South Sudan'**
  String get country_SS;

  /// No description provided for @country_ES.
  ///
  /// In en, this message translates to:
  /// **'Spain'**
  String get country_ES;

  /// No description provided for @country_LK.
  ///
  /// In en, this message translates to:
  /// **'Sri Lanka'**
  String get country_LK;

  /// No description provided for @country_SD.
  ///
  /// In en, this message translates to:
  /// **'Sudan'**
  String get country_SD;

  /// No description provided for @country_SR.
  ///
  /// In en, this message translates to:
  /// **'Suriname'**
  String get country_SR;

  /// No description provided for @country_SJ.
  ///
  /// In en, this message translates to:
  /// **'Svalbard and Jan Mayen Islands'**
  String get country_SJ;

  /// No description provided for @country_SE.
  ///
  /// In en, this message translates to:
  /// **'Sweden'**
  String get country_SE;

  /// No description provided for @country_CH.
  ///
  /// In en, this message translates to:
  /// **'Switzerland'**
  String get country_CH;

  /// No description provided for @country_SY.
  ///
  /// In en, this message translates to:
  /// **'Syria'**
  String get country_SY;

  /// No description provided for @country_TW.
  ///
  /// In en, this message translates to:
  /// **'Taiwan'**
  String get country_TW;

  /// No description provided for @country_TJ.
  ///
  /// In en, this message translates to:
  /// **'Tajikistan'**
  String get country_TJ;

  /// No description provided for @country_TZ.
  ///
  /// In en, this message translates to:
  /// **'Tanzania'**
  String get country_TZ;

  /// No description provided for @country_TH.
  ///
  /// In en, this message translates to:
  /// **'Thailand'**
  String get country_TH;

  /// No description provided for @country_BS.
  ///
  /// In en, this message translates to:
  /// **'The Bahamas'**
  String get country_BS;

  /// No description provided for @country_GM.
  ///
  /// In en, this message translates to:
  /// **'The Gambia '**
  String get country_GM;

  /// No description provided for @country_TL.
  ///
  /// In en, this message translates to:
  /// **'Timor-Leste'**
  String get country_TL;

  /// No description provided for @country_TG.
  ///
  /// In en, this message translates to:
  /// **'Togo'**
  String get country_TG;

  /// No description provided for @country_TK.
  ///
  /// In en, this message translates to:
  /// **'Tokelau'**
  String get country_TK;

  /// No description provided for @country_TO.
  ///
  /// In en, this message translates to:
  /// **'Tonga'**
  String get country_TO;

  /// No description provided for @country_TT.
  ///
  /// In en, this message translates to:
  /// **'Trinidad and Tobago'**
  String get country_TT;

  /// No description provided for @country_TN.
  ///
  /// In en, this message translates to:
  /// **'Tunisia'**
  String get country_TN;

  /// No description provided for @country_TR.
  ///
  /// In en, this message translates to:
  /// **'Turkey'**
  String get country_TR;

  /// No description provided for @country_TM.
  ///
  /// In en, this message translates to:
  /// **'Turkmenistan'**
  String get country_TM;

  /// No description provided for @country_TC.
  ///
  /// In en, this message translates to:
  /// **'Turks and Caicos Islands'**
  String get country_TC;

  /// No description provided for @country_TV.
  ///
  /// In en, this message translates to:
  /// **'Tuvalu'**
  String get country_TV;

  /// No description provided for @country_UG.
  ///
  /// In en, this message translates to:
  /// **'Uganda'**
  String get country_UG;

  /// No description provided for @country_UA.
  ///
  /// In en, this message translates to:
  /// **'Ukraine'**
  String get country_UA;

  /// No description provided for @country_AE.
  ///
  /// In en, this message translates to:
  /// **'United Arab Emirates'**
  String get country_AE;

  /// No description provided for @country_GB.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get country_GB;

  /// No description provided for @country_US.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get country_US;

  /// No description provided for @country_UM.
  ///
  /// In en, this message translates to:
  /// **'United States Minor Outlying Islands'**
  String get country_UM;

  /// No description provided for @country_UY.
  ///
  /// In en, this message translates to:
  /// **'Uruguay'**
  String get country_UY;

  /// No description provided for @country_UZ.
  ///
  /// In en, this message translates to:
  /// **'Uzbekistan'**
  String get country_UZ;

  /// No description provided for @country_VU.
  ///
  /// In en, this message translates to:
  /// **'Vanuatu'**
  String get country_VU;

  /// No description provided for @country_VA.
  ///
  /// In en, this message translates to:
  /// **'Vatican City State (Holy See)'**
  String get country_VA;

  /// No description provided for @country_VE.
  ///
  /// In en, this message translates to:
  /// **'Venezuela'**
  String get country_VE;

  /// No description provided for @country_VN.
  ///
  /// In en, this message translates to:
  /// **'Vietnam'**
  String get country_VN;

  /// No description provided for @country_VG.
  ///
  /// In en, this message translates to:
  /// **'Virgin Islands (British)'**
  String get country_VG;

  /// No description provided for @country_VI.
  ///
  /// In en, this message translates to:
  /// **'Virgin Islands (US)'**
  String get country_VI;

  /// No description provided for @country_WF.
  ///
  /// In en, this message translates to:
  /// **'Wallis and Futuna Islands'**
  String get country_WF;

  /// No description provided for @country_EH.
  ///
  /// In en, this message translates to:
  /// **'Western Sahara'**
  String get country_EH;

  /// No description provided for @country_YE.
  ///
  /// In en, this message translates to:
  /// **'Yemen'**
  String get country_YE;

  /// No description provided for @country_ZM.
  ///
  /// In en, this message translates to:
  /// **'Zambia'**
  String get country_ZM;

  /// No description provided for @country_ZW.
  ///
  /// In en, this message translates to:
  /// **'Zimbabwe'**
  String get country_ZW;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
