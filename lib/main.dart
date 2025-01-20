import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'qr_validator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presensi Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ScannerPage(),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _isProcessing = false;
  bool _hasScanned = false;

  Future<void> _sendData(String qrData) async {
    if (_isProcessing || _hasScanned) return;

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    try {
      QRValidator.validateQrCode(qrData);
      // Cek apakah data kosong
      if (qrData.isEmpty) {
        throw Exception('QR code kosong');
      }

      final String id = qrData.trim();

      // Deteksi tipe pengguna dari kode ID
      final bool isGuru = id.startsWith('G');
      debugPrint('Tipe pengguna: ${isGuru ? 'Guru' : 'Siswa'}');

      // Validasi format kode
      if (isGuru && !id.startsWith('G')) {
        throw Exception('Kode guru harus dimulai dengan G');
      } else if (!isGuru && !id.startsWith('S')) {
        throw Exception('Kode siswa harus dimulai dengan S');
      }

      Map<String, dynamic> requestBody = {
        'mode': isGuru ? 'presensiGuru' : 'presensiSiswa',
        'id': id,
      };

      debugPrint('Sending request: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(
            'https://script.google.com/macros/s/AKfycbyoMUoVtkDVMXZ2rMug-iREQvVP9WDafp_JPoCxyIY4zI9p4afBNf9kvCFibewy-PUm/exec'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 302) {
        final String? redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final redirectResponse = await http.get(Uri.parse(redirectUrl));

          debugPrint(
              'Redirect response status: ${redirectResponse.statusCode}');
          debugPrint('Redirect response body: ${redirectResponse.body}');

          final responseData = jsonDecode(redirectResponse.body);

          if (responseData['status'] == 'success') {
            String message;
            // Data yang dikembalikan dari server sudah lengkap
            if (isGuru) {
              message = '''
Data Guru:
Waktu: ${responseData['data']['timestamp']}
Kode Presensi: ${responseData['data']['kodePresensi']}
Kode Guru: ${responseData['data']['kodeGuru']}
Nama: ${responseData['data']['nama']}
Kehadiran: ${responseData['data']['kehadiran']}
''';
            } else {
              message = '''
Data Siswa:
Waktu: ${responseData['data']['timestamp']}
Kode Presensi: ${responseData['data']['kodePresensi']}
Kode Siswa: ${responseData['data']['kodeSiswa']}
Nama: ${responseData['data']['nama']}
Status Pembayaran: ${responseData['data']['statusPembayaran']}
Kehadiran: ${responseData['data']['kehadiran']}
''';

              // Cek status pembayaran dari response server
              if (responseData['data']['statusPembayaran']
                      ?.toString()
                      .toLowerCase() ==
                  'belum lunas') {
                _showPembayaranDialog(message);
                return;
              }
            }
            _showSuccessDialog(message);
          } else {
            _showGeneralErrorDialog(
                responseData['message'] ?? 'Gagal memproses data');
          }
        }
      } else {
        throw Exception('Gagal mengirim data ke server');
      }
    } catch (e) {
      _showGeneralErrorDialog(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Dialog untuk presensi berhasil (warna normal)
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Presensi Berhasil'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hasScanned = false;
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Dialog khusus untuk siswa yang belum lunas (warna merah)
  void _showPembayaranDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pembayaran Belum Lunas'),
        content: Text(message),
        backgroundColor: Colors.red,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hasScanned = false;
              });
              Navigator.pop(context);
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog untuk error umum (warna normal)
  void _showGeneralErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hasScanned = false;
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Di dalam class _ScannerPageState
  void validateQrCode(String qrData) {
    if (qrData.isEmpty) {
      throw Exception('QR code kosong');
    }

    if (!qrData.startsWith('G') && !qrData.startsWith('S')) {
      throw Exception('Format kode tidak valid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presensi Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 300,
              width: 300,
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      debugPrint('Barcode found! ${barcode.rawValue}');
                      _sendData(barcode.rawValue!);
                    }
                  }
                },
              ),
            ),
            if (_isProcessing) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Arahkan kamera ke Barcode atau QR Code',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
