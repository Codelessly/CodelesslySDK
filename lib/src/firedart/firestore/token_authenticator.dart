import 'package:grpc/grpc.dart';

import '../auth/firebase_auth.dart';

class TokenAuthenticator {
  final FirebaseAuth auth;

  TokenAuthenticator._internal(this.auth);

  factory TokenAuthenticator.from(FirebaseAuth auth) {
    return TokenAuthenticator._internal(auth);
  }

  Future<void> authenticate(Map<String, String> metadata, String uri) async {
    var idToken = await auth.tokenProvider.idToken;
    metadata['authorization'] = 'Bearer $idToken';
  }

  CallOptions get toCallOptions => CallOptions(providers: [authenticate]);
}
