import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_common/auth/auth_provider.dart';
import 'package:flutter_common/auth/email_auth.dart';
import 'package:flutter_common/l10n/app_localizations.dart';
import 'package:flutter_common/util/layout.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.showGoogle,
    required this.showMicrosoft,
    required this.showApple,
    required this.termOfServiceUrl,
    required this.privacyPolicyUrl,
  });
  final bool showGoogle;
  final bool showMicrosoft;
  final bool showApple;
  final String termOfServiceUrl;
  final String privacyPolicyUrl;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _isLoggingIn = false;

  Widget getUserAgreement(BuildContext context) {
    final style = TextButton.styleFrom(
      overlayColor: Colors.transparent,
      padding: EdgeInsets.zero,
      alignment: Alignment.bottomCenter,
      minimumSize: Size(0, 17),
    );
    switch (Localizations.localeOf(context).languageCode) {
      case 'zh':
        return Text.rich(
          softWrap: true,
          style: Theme.of(context).textTheme.bodySmall,
          TextSpan(
            children: [
              TextSpan(text: '登录即表示您同意'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: TextButton(
                  style: style,
                  onPressed: () {
                    launchUrl(Uri.parse(widget.termOfServiceUrl));
                  },
                  child: Text(
                    '用户协议',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              TextSpan(text: '并确认已阅读'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: TextButton(
                  style: style,
                  onPressed: () {
                    launchUrl(Uri.parse(widget.privacyPolicyUrl));
                  },
                  child: Text(
                    '隐私政策',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'en':
        return Text.rich(
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
          TextSpan(
            children: [
              TextSpan(text: 'By logging in, you agree to the '),
              WidgetSpan(
                child: TextButton(
                  style: style,
                  onPressed: () {
                    launchUrl(Uri.parse(widget.termOfServiceUrl));
                  },
                  child: Text(
                    'Term of Service',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              TextSpan(text: ' and acknowledge that you have read our '),
              WidgetSpan(
                child: TextButton(
                  style: style,
                  onPressed: () {
                    launchUrl(Uri.parse(widget.privacyPolicyUrl));
                  },
                  child: Text(
                    'Privacy Policy',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<bool> getUserConsent() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final result = await showDialog<bool?>(
        context: context,
        builder: (context) => AlertDialog(
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              AppLocalizations.of(context)!.userConsend,
              maxLines: 10,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.disagree),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.okay),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return _isLoggingIn
        ? const Center(child: CircularProgressIndicator())
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.login,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () async {
                  if (!await getUserConsent()) {
                    return;
                  }
                  if (context.mounted) {
                    if (fullScreenLayout(context)) {
                      await Navigator.of(context, rootNavigator: true).push(
                        CupertinoPageRoute(
                          builder: (ctx) => Scaffold(
                            appBar: AppBar(
                              title: Text(AppLocalizations.of(context)!.login),
                            ),
                            body: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: EmailAuth(),
                            ),
                          ),
                        ),
                      );
                    } else {
                      await showDialog(
                        context: context,
                        barrierLabel: AppLocalizations.of(context)!.emailLogin,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: AppBar(
                            automaticallyImplyLeading: true,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            title: Text(AppLocalizations.of(context)!.login),
                          ),
                          content: EmailAuth(),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.email_outlined, size: 24),
                label: Text(AppLocalizations.of(context)!.email),
                style: FilledButton.styleFrom(minimumSize: const Size(270, 50)),
              ),
              if (widget.showGoogle)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final authProvider = context.read<AuthProvider>();
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      if (!await getUserConsent()) {
                        return;
                      }
                      setState(() {
                        _isLoggingIn = true;
                      });
                      try {
                        await authProvider.signInWithGoogle();
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      } finally {
                        setState(() {
                          _isLoggingIn = false;
                        });
                      }
                    },
                    icon: Image.asset(
                      'assets/icons/google.png',
                      width: 24,
                      height: 24,
                    ),
                    label: Text(AppLocalizations.of(context)!.google),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(270, 50),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (widget.showApple)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final authProvider = context.read<AuthProvider>();
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      if (!await getUserConsent()) {
                        return;
                      }
                      setState(() {
                        _isLoggingIn = true;
                      });
                      try {
                        await authProvider.signInWithApple();
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      } finally {
                        setState(() {
                          _isLoggingIn = false;
                        });
                      }
                    },
                    icon: const Icon(Icons.apple_rounded, size: 24),
                    label: Text(AppLocalizations.of(context)!.apple),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(270, 50),
                    ),
                  ),
                ),
              if (widget.showMicrosoft)
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    if (!await getUserConsent()) {
                      return;
                    }
                    setState(() {
                      _isLoggingIn = true;
                    });
                    try {
                      authProvider.signInWithMicrosoft();
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    } finally {
                      setState(() {
                        _isLoggingIn = false;
                      });
                    }
                  },
                  icon: Image.asset(
                    'assets/icons/microsoft_logo.png',
                    width: 24,
                    height: 24,
                  ),
                  label: Text(AppLocalizations.of(context)!.microsoft),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(270, 50),
                  ),
                ),
              const SizedBox(height: 5),
              getUserAgreement(context),
              const SizedBox(height: 5),
            ],
          );
  }
}
