import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:memo_life/features/notes/data/note_lock_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthenticationOptions());
  });

  late _MockLocalAuthentication auth;
  late NoteLockService service;

  setUp(() {
    auth = _MockLocalAuthentication();
    service = NoteLockService(auth);
  });

  test('authenticate returns true without prompting when the device has no lock configured', () async {
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => false);

    expect(await service.authenticate(), isTrue);
    verifyNever(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        options: any(named: 'options'),
      ),
    );
  });

  test(
    'authenticate delegates to LocalAuthentication when the device has a lock',
    () async {
      when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
      when(
        () => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => true);

      expect(await service.authenticate(), isTrue);
    },
  );

  test(
    'authenticate returns false when the platform throws (e.g. locked out)',
    () async {
      when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
      when(
        () => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        ),
      ).thenThrow(Exception('locked out'));

      expect(await service.authenticate(), isFalse);
    },
  );
}
