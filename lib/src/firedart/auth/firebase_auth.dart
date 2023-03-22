import 'package:http/http.dart' as http;

import 'auth_gateway.dart';
import 'client.dart';
import 'token_provider.dart';
import 'token_store.dart';
import 'user_gateway.dart';

class FirebaseAuth {
  /* Singleton interface */
  static FirebaseAuth? _instance;

  UserClient get client => _userGateway.client;

  static FirebaseAuth? initialize(String apiKey, TokenStore tokenStore) {
    if (_instance != null) {
      throw Exception('FirebaseAuth instance was already initialized');
    }
    _instance = FirebaseAuth(apiKey, tokenStore);
    return _instance;
  }

  static FirebaseAuth? get instance {
    if (_instance == null) {
      throw Exception(
          "FirebaseAuth hasn't been initialized. Please call FirebaseAuth.initialize() before using it.");
    }
    return _instance;
  }

  /* Instance interface */
  final String apiKey;

  late TokenProvider tokenProvider;

  late AuthGateway _authGateway;
  late UserGateway _userGateway;

  FirebaseAuth(this.apiKey, TokenStore tokenStore, {http.Client? httpClient})
      : assert(apiKey.isNotEmpty) {
    var keyClient = KeyClient(httpClient ?? http.Client(), apiKey);
    tokenProvider = TokenProvider(keyClient, tokenStore);

    _authGateway = AuthGateway(keyClient, tokenProvider);
    _userGateway = UserGateway(keyClient, tokenProvider);
  }

  bool get isSignedIn => tokenProvider.isSignedIn;

  Stream<bool> get signInState => tokenProvider.signInState;

  String? get userId => tokenProvider.userId;

  Future<User> signUp(String email, String password) =>
      _authGateway.signUp(email, password);

  Future<User> signIn(String email, String password) =>
      _authGateway.signIn(email, password);

  Future<User> signInAnonymously() => _authGateway.signInAnonymously();

  void signOut() => tokenProvider.signOut();

  Future<void> resetPassword(String email) => _authGateway.resetPassword(email);

  Future<void> requestEmailVerification() =>
      _userGateway.requestEmailVerification();

  Future<void> changePassword(String password) =>
      _userGateway.changePassword(password);

  Future<User> getUser() => _userGateway.getUser();

  Future<void> updateProfile({String? displayName, String? photoUrl}) =>
      _userGateway.updateProfile(displayName, photoUrl);

  Future<void> deleteAccount() async {
    await _userGateway.deleteAccount();
    signOut();
  }
}
