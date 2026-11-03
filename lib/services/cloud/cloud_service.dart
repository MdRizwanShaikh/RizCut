import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../storage/draft_store.dart';
import 'firebase_config.dart';

/// Optional account + backup. Everything else in the app works without it.
///
/// Cost stays near zero: auth is Firebase's free tier, and the only network
/// calls are the ones the user triggers (sign in, back up, restore). Backups
/// hold project JSON only, never video files.
class CloudService extends ChangeNotifier {
  CloudService._();
  static final instance = CloudService._();

  bool _ready = false;
  User? _user;
  StreamSubscription<User?>? _sub;

  /// Firebase is configured in this build and initialised.
  bool get available => _ready;
  User? get user => _user;
  bool get signedIn => _user != null;

  Future<void> init() async {
    if (!FirebaseConfig.isConfigured || _ready) return;
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      if (!kIsWeb) {
        await GoogleSignIn.instance.initialize(
          serverClientId: FirebaseConfig.googleServerClientId.isEmpty
              ? null
              : FirebaseConfig.googleServerClientId,
        );
      }
      _ready = true;
      _sub = FirebaseAuth.instance.authStateChanges().listen((u) {
        _user = u;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    _requireReady();
    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      return;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google did not return an ID token. '
          'Check GOOGLE_SERVER_CLIENT_ID and the app SHA-1 in Firebase.');
    }
    await FirebaseAuth.instance
        .signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  /// Signs in, or creates the account if the email is new.
  Future<void> signInWithEmail(String email, String password) async {
    _requireReady();
    final auth = FirebaseAuth.instance;
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        try {
          await auth.createUserWithEmailAndPassword(
              email: email, password: password);
          return;
        } on FirebaseAuthException catch (e2) {
          if (e2.code != 'email-already-in-use') rethrow;
        }
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!_ready) return;
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }

  CollectionReference<Map<String, dynamic>> _drafts(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('drafts');

  /// Uploads every local draft. Returns how many were saved.
  Future<int> backUp() async {
    final u = _requireUser();
    final drafts = await DraftStore.instance.list();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in drafts) {
      batch.set(_drafts(u.uid).doc(d.id), {
        'json': jsonEncode(d.toJson()),
        'updated': d.updatedAt.millisecondsSinceEpoch,
      });
    }
    await batch.commit();
    return drafts.length;
  }

  /// Downloads drafts from the cloud and merges them (newest wins).
  Future<int> restore() async {
    final u = _requireUser();
    final snap = await _drafts(u.uid).get();
    final local = {for (final d in await DraftStore.instance.list()) d.id: d};
    var count = 0;
    for (final doc in snap.docs) {
      try {
        final d = Draft.fromJson(
            (jsonDecode(doc.data()['json'] as String) as Map).cast());
        final mine = local[d.id];
        if (mine == null || mine.updatedAt.isBefore(d.updatedAt)) {
          await DraftStore.instance.save(d);
          count++;
        }
      } catch (_) {
        // Skip drafts saved by a newer app version.
      }
    }
    return count;
  }

  /// Deletes cloud backups and the account (Play policy: in-app deletion).
  Future<void> deleteAccount() async {
    final u = _requireUser();
    final snap = await _drafts(u.uid).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(FirebaseFirestore.instance.collection('users').doc(u.uid));
    await batch.commit();
    await u.delete();
    await signOut();
  }

  void _requireReady() {
    if (!_ready) throw StateError('Cloud backup is not set up in this build.');
  }

  User _requireUser() {
    _requireReady();
    final u = _user;
    if (u == null) throw StateError('Sign in first.');
    return u;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Short, user-facing text for auth/backup errors.
String cloudErrorText(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'invalid-email' => 'That email address looks wrong.',
      'weak-password' => 'Use a password with at least 6 characters.',
      'wrong-password' || 'invalid-credential' => 'Email or password is wrong.',
      'email-already-in-use' => 'That email already has an account. Check the password.',
      'requires-recent-login' => 'Please sign out, sign in again, then retry.',
      'network-request-failed' => 'No internet connection.',
      _ => e.message ?? 'Sign-in failed (${e.code}).',
    };
  }
  if (e is GoogleSignInException) {
    return e.code == GoogleSignInExceptionCode.canceled
        ? 'Sign-in cancelled.'
        : 'Google sign-in failed: ${e.description ?? e.code.name}';
  }
  if (e is FirebaseException) return e.message ?? 'Cloud error (${e.code}).';
  if (e is StateError) return e.message;
  return '$e';
}
