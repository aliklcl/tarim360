enum AuthMode { local, firebase }

class AuthSession {
  const AuthSession({
    required this.mode,
    required this.userId,
    required this.displayName,
    required this.cloudEnabled,
    this.email,
    this.sharedFarmCode,
    this.familyId,
    this.familyName,
    this.familyAccessCode,
    this.isFamilyOwner = false,
  });

  final AuthMode mode;
  final String userId;
  final String displayName;
  final bool cloudEnabled;
  final String? email;
  final String? sharedFarmCode;
  final String? familyId;
  final String? familyName;
  final String? familyAccessCode;
  final bool isFamilyOwner;

  AuthSession copyWith({
    AuthMode? mode,
    String? userId,
    String? displayName,
    bool? cloudEnabled,
    String? email,
    String? sharedFarmCode,
    String? familyId,
    String? familyName,
    String? familyAccessCode,
    bool? isFamilyOwner,
  }) {
    return AuthSession(
      mode: mode ?? this.mode,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      cloudEnabled: cloudEnabled ?? this.cloudEnabled,
      email: email ?? this.email,
      sharedFarmCode: sharedFarmCode ?? this.sharedFarmCode,
      familyId: familyId ?? this.familyId,
      familyName: familyName ?? this.familyName,
      familyAccessCode: familyAccessCode ?? this.familyAccessCode,
      isFamilyOwner: isFamilyOwner ?? this.isFamilyOwner,
    );
  }
}
