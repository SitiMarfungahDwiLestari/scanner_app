class QRValidator {
  static void validateQrCode(String qrData) {
    if (qrData.isEmpty) {
      throw Exception('QR code kosong');
    }

    if (!qrData.startsWith('G') && !qrData.startsWith('S')) {
      throw Exception('Format kode tidak valid');
    }
  }
}
