import 'package:flutter_test/flutter_test.dart';

import '../lib/qr_validator.dart';

void main() {
  group('QR Code Validation Tests', () {
    test('Valid student code starts with S (U1)', () {
      expect(() => QRValidator.validateQrCode("S0001"), returnsNormally);
    });

    test('Valid teacher code starts with G (U2)', () {
      expect(() => QRValidator.validateQrCode("G0002"), returnsNormally);
    });

    test('Invalid code format throws exception (U3)', () {
      expect(
          () => QRValidator.validateQrCode("X0001"),
          throwsA(isA<Exception>().having((error) => error.toString(),
              'message', contains('Format kode tidak valid'))));
    });
  });
}
