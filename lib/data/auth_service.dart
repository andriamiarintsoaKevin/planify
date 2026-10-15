import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signUp({required String email, required String password}) async {
    try {
      await _client.auth.signUp(email: email.trim(), password: password);
    } on AuthRetryableFetchException {
      throw const AuthFailure(
        'Connexion réseau impossible. Vérifiez Internet et réessayez.',
      );
    } on AuthException catch (error) {
      throw AuthFailure(_messageFor(error, action: 'inscription'));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthRetryableFetchException {
      throw const AuthFailure(
        'Connexion réseau impossible. Vérifiez Internet et réessayez.',
      );
    } on AuthException catch (error) {
      throw AuthFailure(_messageFor(error, action: 'connexion'));
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthRetryableFetchException {
      throw const AuthFailure(
        'Déconnexion impossible sans accès réseau. Réessayez.',
      );
    } on AuthException catch (error) {
      throw AuthFailure(_messageFor(error, action: 'déconnexion'));
    }
  }

  String _messageFor(AuthException error, {required String action}) {
    return switch (error.code) {
      'invalid_credentials' => 'Adresse e-mail ou mot de passe incorrect.',
      'email_not_confirmed' =>
        'Confirmez votre adresse e-mail avant de vous connecter.',
      'weak_password' =>
        'Le mot de passe ne respecte pas les critères de sécurité.',
      'email_address_invalid' || 'validation_failed' =>
        'Vérifiez l’adresse e-mail et le mot de passe saisis.',
      'signup_disabled' || 'email_provider_disabled' =>
        'Les inscriptions par e-mail sont désactivées dans le projet Supabase.',
      'email_exists' || 'user_already_exists' =>
        'Cette adresse est peut-être déjà inscrite. Essayez de vous connecter.',
      'over_email_send_rate_limit' || 'over_request_rate_limit' =>
        'Trop de tentatives. Attendez un peu avant de réessayer.',
      _ => _diagnosticMessage(error, action: action),
    };
  }

  String _diagnosticMessage(AuthException error, {required String action}) {
    final details = [
      if (error.code != null) 'code ${error.code}',
      if (error.statusCode != null) 'HTTP ${error.statusCode}',
    ];
    final suffix = details.isEmpty ? '' : ' (${details.join(', ')})';
    return 'L’$action a échoué$suffix. Vérifiez le fournisseur e-mail et les '
        'journaux Auth du projet Supabase.';
  }
}
