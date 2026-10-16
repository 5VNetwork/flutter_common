import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_common/auth/auth_provider.dart';
import 'package:flutter_common/common.dart';
import 'package:flutter_common/l10n/app_localizations.dart';
import 'package:flutter_common/widgets/count_down_timer.dart';

class EmailAuth extends StatefulWidget {
  /// When true, only domains in the email whitelist asset are allowed.
  /// When false (default), domains in the disposable email blocklist are rejected.
  const EmailAuth({super.key, this.useWhitelist = false});

  final bool useWhitelist;

  @override
  State<EmailAuth> createState() => _EmailAuthState();
}

class _EmailAuthState extends State<EmailAuth> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _useOtp = true;
  bool _isCounting = false;
  bool _isSendingOtp = false;
  bool _isLoggingIn = false;
  String? _sendOtpError;
  String? _emailError;
  String? _passwordError;
  Set<String> _emailDomains = {};

  @override
  initState() {
    super.initState();
    _loadEmailDomainList();
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
  }

  Future<void> _loadEmailDomainList() async {
    final assetPath = widget.useWhitelist
        ? 'packages/flutter_common/assets/email_white_list.txt'
        : 'packages/flutter_common/assets/disposable_email_blocklist.conf';
    try {
      final content = await rootBundle.loadString(assetPath);
      final domains = content
          .split('\n')
          .map((line) => line.trim().toLowerCase())
          .where((line) => line.isNotEmpty)
          .toSet();
      setState(() {
        _emailDomains = domains;
      });
      // Re-validate in case the user already typed an email.
      _validateEmail();
    } catch (e) {
      debugPrint('Failed to load email domain list ($assetPath): $e');
    }
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = null);
      return;
    }

    if (!validEmail(email)) {
      setState(() => _emailError = null);
      return;
    }

    // Extract domain from email
    final domain = email.split('@').last.toLowerCase();
    final rejected = widget.useWhitelist
        ? !_emailDomains.contains(domain)
        : _emailDomains.contains(domain);

    if (rejected) {
      setState(() {
        _emailError = AppLocalizations.of(context)!.pleaseUseAnotherEmail;
      });
    } else {
      setState(() => _emailError = null);
    }
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      _passwordError = password.isEmpty
          ? AppLocalizations.of(context)!.passwordRequired
          : null;
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.removeListener(_validatePassword);
    _passwordController.dispose();
    super.dispose();
  }

  List<Widget> _buildContent() {
    return [
      TextField(
        controller: _emailController,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: AppLocalizations.of(context)!.email,
          errorText: _emailError,
          errorMaxLines: 2,
        ),
      ),
      const SizedBox(height: 10),
      if (_useOtp)
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.verificationCode,
            errorText: _sendOtpError,
            errorMaxLines: 10,
            suffixIcon: _isCounting
                ? Padding(
                    padding: const EdgeInsets.only(right: 5.0),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: Center(
                        child: CountdownTimer(
                          textStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          onFinished: () {
                            setState(() => _isCounting = !_isCounting);
                          },
                        ),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: () async {
                      final email = _emailController.text.trim();
                      if (email.isNotEmpty &&
                          emailRegExp.hasMatch(email) &&
                          _emailError == null) {
                        setState(() {
                          _isSendingOtp = true;
                          _sendOtpError = null;
                        });
                        try {
                          await context.read<AuthProvider>().signInWithEmailOtp(
                            email,
                          );
                        } catch (e) {
                          setState(() => _sendOtpError = e.toString());
                        }
                        setState(() {
                          _isCounting = true;
                          _isSendingOtp = false;
                        });
                      }
                    },
                    child: _isSendingOtp
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(AppLocalizations.of(context)!.send),
                  ),
          ),
        )
      else
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.password,
            errorText: _passwordError,
          ),
        ),
      const SizedBox(height: 2),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {
            setState(() {
              _useOtp = !_useOtp;
              _isCounting = false;
              _isSendingOtp = false;
              _sendOtpError = null;
              _passwordError = null;
            });
          },
          child: Text(
            _useOtp
                ? AppLocalizations.of(context)!.usePassword
                : AppLocalizations.of(context)!.useOtp,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () async {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final email = _emailController.text.trim();
          if (_useOtp) {
            if (email.isNotEmpty &&
                emailRegExp.hasMatch(email) &&
                _emailError == null &&
                _otpController.text.trim().isNotEmpty) {
              setState(() => _isLoggingIn = true);
              try {
                await context.read<AuthProvider>().verifyEmailOtp(
                  email,
                  _otpController.text.trim(),
                );
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              } finally {
                setState(() => _isLoggingIn = false);
              }
            }
          } else {
            final password = _passwordController.text.trim();
            if (email.isNotEmpty &&
                emailRegExp.hasMatch(email) &&
                _emailError == null &&
                password.isNotEmpty) {
              setState(() => _isLoggingIn = true);
              try {
                await context.read<AuthProvider>().signInWithEmailPassword(
                  email,
                  password,
                );
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              } finally {
                setState(() => _isLoggingIn = false);
              }
            }
          }
        },
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        child: _isLoggingIn
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Text(AppLocalizations.of(context)!.login),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: _buildContent());
  }
}
