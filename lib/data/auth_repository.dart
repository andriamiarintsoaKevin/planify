import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

abstract interface class AuthRepository {
  User? get currentUser;

  Stream<AuthState> get authStateChanges;

  Future<void> signUp({required String email, required String password});

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(SupabaseClient client)
    : _service = AuthService(client);

  final AuthService _service;

  @override
  User? get currentUser => _service.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _service.authStateChanges;

  @override
  Future<void> signUp({required String email, required String password}) =>
      _service.signUp(email: email, password: password);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _service.signIn(email: email, password: password);

  @override
  Future<void> signOut() => _service.signOut();
}
