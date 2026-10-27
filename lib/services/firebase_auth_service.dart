import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../cloud_sync_service.dart';

class FirebaseAuthService {
  FirebaseAuthService._();

  static Future<UserCredential> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
    } catch (_) {}

    // ignore: unnecessary_nullable_for_final_variable_declarations
    final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
    if (googleUser == null) {
      throw Exception('Google girişi iptal edildi.');
    }
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  static Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<UserCredential> signInAnonymously() {
    return FirebaseAuth.instance.signInAnonymously();
  }

  static Future<void> sendPasswordResetEmail(String email) {
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  static User? currentUser() => FirebaseAuth.instance.currentUser;

  static Future<void> signOut() async {
    CloudSyncService.instance.temizleCache();
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
