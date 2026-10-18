import 'package:supabase_flutter/supabase_flutter.dart';

const String deleteAccountFunctionName = 'delete-account';

class AccountDeletionFailure implements Exception {
  const AccountDeletionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

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

  Future<void> deleteAccount() async {
    if (_client.auth.currentSession == null) {
      throw const AccountDeletionFailure(
        'Reconnectez-vous avant de supprimer votre compte.',
      );
    }

    try {
      final response = await _client.functions.invoke(
        deleteAccountFunctionName,
        body: const <String, Object?>{},
      );
      if (response.data is! Map || response.data['success'] != true) {
        throw const AccountDeletionFailure(
          'La suppression du compte n’a pas été confirmée par le serveur.',
        );
      }
    } on AccountDeletionFailure {
      rethrow;
    } on FunctionException catch (error) {
      if (error.status == 0) {
        throw const AccountDeletionFailure(
          'Connexion impossible. Vérifiez votre réseau puis réessayez.',
        );
      }
      if (error.status == 401) {
        throw const AccountDeletionFailure(
          'Votre session a expiré. Reconnectez-vous puis réessayez.',
        );
      }
      throw const AccountDeletionFailure(
        'Le serveur n’a pas pu supprimer le compte. Réessayez plus tard.',
      );
    }

    await _client.auth.signOut(scope: SignOutScope.local);
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
