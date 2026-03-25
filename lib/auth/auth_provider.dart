import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:rxdart/subjects.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

abstract class AuthProvider with ChangeNotifier {
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signInWithMicrosoft();
  Future<void> signInWithEmailOtp(String email);
  Future<void> verifyEmailOtp(String email, String otp);
  Future<void> logOut();
  Stream<Session?> get sessionStreams;
  Session? get currentSession;
  Future<void> refreshUser();
  Future<void> deleteAccount();
}

class SupabaseAuth extends AuthProvider {
  SupabaseAuth({
    required this.webClientId,
    required this.iosClientId,
    required this.loginCallbackUrl,
  }) {
    _userController = BehaviorSubject<Session?>.seeded(currentSession);
    supabase.auth.onAuthStateChange.forEach((event) {
      if (event.session != null) {
        _userController.add(event.session);
      } else {
        _userController.add(null);
      }
      notifyListeners();
    });
  }

  final String webClientId;
  final String iosClientId;
  final String loginCallbackUrl;
  final supabase = Supabase.instance.client;
  late final BehaviorSubject<Session?> _userController;

  @override
  Stream<Session?> get sessionStreams {
    return _userController.stream;
  }

  @override
  Session? get currentSession {
    if (supabase.auth.currentSession == null) {
      return null;
    }
    return supabase.auth.currentSession;
  }

  @override
  Future<void> refreshUser() async {
    // Refresh the session to get updated JWT claims
    await supabase.auth.refreshSession();
    final session = supabase.auth.currentSession;
    if (session == null) {
      _userController.add(null);
      return;
    }
    _userController.add(session);
  }

  /// Performs Apple sign in on iOS or macOS
  @override
  Future<AuthResponse> signInWithApple() async {
    final rawNonce = supabase.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException(
        'Could not find ID Token from generated credential.',
      );
    }
    return supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final scopes = ['email', 'profile'];
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: webClientId,
        clientId: Platform.isIOS ? iosClientId : null,
      );
      GoogleSignInAccount? googleUser = await googleSignIn
          .attemptLightweightAuthentication();
      // or await googleSignIn.authenticate(); which will return a GoogleSignInAccount or throw an exception
      if (googleUser == null) {
        googleUser = await googleSignIn.authenticate();
        // throw AuthException('Failed to sign in with Google.');
      }
      /// Authorization is required to obtain the access token with the appropriate scopes for Supabase authentication,
      /// while also granting permission to access user information.
      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw AuthException('No ID Token found.');
      }
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
    } else {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: loginCallbackUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    }
  }

  @override
  Future<void> signInWithMicrosoft() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.azure,
      redirectTo: loginCallbackUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> signInWithEmailOtp(String email) async {
    await supabase.auth.signInWithOtp(
      email: email,
      emailRedirectTo: loginCallbackUrl,
      shouldCreateUser: true,
    );
  }

  @override
  Future<void> verifyEmailOtp(String email, String otp) async {
    await supabase.auth.verifyOTP(
      email: email,
      token: otp,
      type: OtpType.email,
    );
  }

  @override
  Future<void> logOut() async {
    try {
      await Future.wait([
        // _firebaseAuth.signOut(),
        // _googleSignIn.signOut(),
        supabase.auth.signOut(),
      ]);
    } catch (_) {
      throw 'Log out failed';
    }
  }

  @override
  Future<void> deleteAccount() async {
    if (currentSession == null) {
      throw 'No Current User';
    }
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) {
      throw 'No Token';
    }
    await supabase.functions.invoke(
      'delete-account',
      headers: {'Authorization': 'Bearer $token'},
    );
    supabase.auth.signOut();
  }
}
