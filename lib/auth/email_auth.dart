import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_common/auth/auth_provider.dart';
import 'package:flutter_common/common.dart';
import 'package:flutter_common/l10n/app_localizations.dart';
import 'package:flutter_common/widgets/count_down_timer.dart';

class EmailAuth extends StatefulWidget {
  const EmailAuth({super.key});
  @override
  State<EmailAuth> createState() => _EmailAuthState();
}

class _EmailAuthState extends State<EmailAuth> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isCounting = false;
  bool _isSendingOtp = false;
  bool _isLoggingIn = false;
  String? _sendOtpError;
  String? _emailError;
  Set<String> _disposableEmailDomains = {};

  @override
  initState() {
    super.initState();
    _loadDisposableEmailBlocklist();
    _emailController.addListener(_validateEmail);
  }

  Future<void> _loadDisposableEmailBlocklist() async {
    try {
      final content = await rootBundle.loadString(
        'assets/disposable_email_blocklist.conf',
      );
      final domains = content
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toSet();
      setState(() {
        _disposableEmailDomains = domains;
      });
    } catch (e) {
      // If blocklist fails to load, continue without blocking
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

    if (_disposableEmailDomains.contains(domain)) {
      setState(() {
        _emailError = AppLocalizations.of(context)!.pleaseUseAnotherEmail;
      });
    } else {
      setState(() => _emailError = null);
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _emailController.dispose();
    _otpController.dispose();
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
                    if (_emailController.text.isNotEmpty &&
                        emailRegExp.hasMatch(_emailController.text) &&
                        _emailError == null) {
                      setState(() {
                        _isSendingOtp = true;
                        _sendOtpError = null;
                      });
                      try {
                        await context.read<AuthProvider>().signInWithEmailOtp(
                          _emailController.text,
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
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () async {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          if (_emailController.text.isNotEmpty &&
              emailRegExp.hasMatch(_emailController.text) &&
              _emailError == null &&
              _otpController.text.isNotEmpty) {
            setState(() => _isLoggingIn = true);
            try {
              await context.read<AuthProvider>().verifyEmailOtp(
                _emailController.text,
                _otpController.text,
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
