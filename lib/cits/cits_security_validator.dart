import 'dart:typed_data';

enum CitsVerificationState { notConfigured, verified, rejected, error }

class CitsVerificationResult {
  const CitsVerificationResult({
    required this.state,
    required this.validatorId,
    required this.detail,
  });

  final CitsVerificationState state;
  final String validatorId;
  final String detail;

  Map<String, String> toJson() => <String, String>{
        'state': state.name,
        'validatorId': validatorId,
        'detail': detail,
      };
}

abstract interface class CitsSecurityValidator {
  CitsVerificationResult validate(
    Uint8List rawFrame,
    Map<String, Object?> decodedEnvelope,
  );
}

class NoCitsSecurityValidator implements CitsSecurityValidator {
  const NoCitsSecurityValidator();

  @override
  CitsVerificationResult validate(
    Uint8List rawFrame,
    Map<String, Object?> decodedEnvelope,
  ) {
    return const CitsVerificationResult(
      state: CitsVerificationState.notConfigured,
      validatorId: 'none',
      detail: 'Raw frame retained; PKI verification module not configured.',
    );
  }
}
