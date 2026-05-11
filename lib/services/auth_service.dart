// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

/// ID를 가상 이메일로 변환 (Firebase Auth는 이메일 방식만 지원)
/// 예: "홍길동" → "홍길동@yugioh.app"
String idToEmail(String id) => '${id.trim()}@yugioh.app';

class AuthService {
  final _auth = FirebaseAuth.instance;

  /// 현재 로그인된 유저 (null이면 비로그인)
  User? get currentUser => _auth.currentUser;

  /// 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── 회원가입 ────────────────────────────────────────────────
  Future<AuthResult> signUp({
    required String userId,     // ID (한글/영문 자유)
    required String password,
    required String displayName,
  }) async {
    try {
      final email = idToEmail(userId);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.reload();
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('알 수 없는 오류가 발생했습니다.');
    }
  }

  // ── 로그인 ──────────────────────────────────────────────────
  Future<AuthResult> signIn({
    required String userId,
    required String password,
  }) async {
    try {
      final email = idToEmail(userId);
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('알 수 없는 오류가 발생했습니다.');
    }
  }

  // ── 닉네임 변경 ──────────────────────────────────────────────
  Future<AuthResult> updateDisplayName(String newName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult.error('로그인이 필요합니다.');
      await user.updateDisplayName(newName.trim());
      await user.reload();
      return AuthResult.success();
    } catch (e) {
      return AuthResult.error('닉네임 변경에 실패했습니다.');
    }
  }

  // ── 비밀번호 변경 ────────────────────────────────────────────
  Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult.error('로그인이 필요합니다.');

      // 재인증
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_authErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('비밀번호 변경에 실패했습니다.');
    }
  }

  // ── 로그아웃 ────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Firebase 에러 → 한국어 ────────────────────────────────
  String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '이미 사용 중인 아이디입니다.';
      case 'invalid-email':
        return '사용할 수 없는 아이디입니다.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 합니다.';
      case 'user-not-found':
        return '등록되지 않은 아이디입니다.';
      case 'wrong-password':
      case 'invalid-credential':
        return '아이디 또는 비밀번호가 올바르지 않습니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'too-many-requests':
        return '너무 많은 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      default:
        return '오류가 발생했습니다. ($code)';
    }
  }
}

// ── 결과 타입 ────────────────────────────────────────────────
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;

  const AuthResult._({required this.isSuccess, this.errorMessage});

  factory AuthResult.success() => const AuthResult._(isSuccess: true);
  factory AuthResult.error(String msg) =>
      AuthResult._(isSuccess: false, errorMessage: msg);
}
