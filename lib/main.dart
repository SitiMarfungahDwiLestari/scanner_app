import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      final String cleanQrData =
          qrData.startsWith('|') ? qrData.substring(1) : qrData;

      final List<String> dataParts = cleanQrData.split('|');
      
      debugPrint('Total bagian QR Data: ${dataParts.length}');
      debugPrint('Semua bagian QR Data: $dataParts');

      // Get the ID first to determine if it's a teacher or student
      if (dataParts.isEmpty) {
        throw Exception('QR code kosong');
      }

      final String id = dataParts[0].trim();
      final bool isGuru = id.startsWith('G');

      // Different validation for teacher and student
      if (isGuru) {
        if (dataParts.length < 7) { // Minimal perlu ID dan nama
          throw Exception('Format QR code guru tidak valid');
        }
      } else {
        if (dataParts.length < 20) { // Untuk siswa tetap perlu 20 data
          throw Exception('Format QR code siswa tidak valid');
        }
      }

      final String nama = dataParts[1].trim();
      // Status pembayaran hanya untuk siswa
      final String statusPembayaran = !isGuru ? dataParts[19].trim() : '';

      Map<String, dynamic> requestBody = {
        'mode': isGuru ? 'presensiGuru' : 'presensiSiswa',
        'id': id,
        'namaLengkap': nama,
        if (!isGuru) 'statusPembayaran': statusPembayaran,
      };

      debugPrint('Sending request: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(
            'https://script.google.com/macros/s/AKfycbxQ30OJ77ZbzVFziAaUNofRuZYy-FVK6LCAzELBwS28rJg__nKHOu9ni52HrqAUW72f/exec'),
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
            if (isGuru) {
              message = 'Data Guru:\nKode: $id\nNama: $nama';
            } else {
              message = 'Data Siswa:\nKode: $id\nNama: $nama\nStatus Pembayaran: $statusPembayaran';
            }

            if (responseData['data'] != null) {
              message += '\n\nKode Presensi: ${responseData['data']['kodePresensi']}';
              message += '\nWaktu: ${responseData['data']['timestamp']}';
            }

            // Only show red dialog for students with "belum lunas" status
            if (!isGuru && statusPembayaran.toLowerCase() == 'belum lunas') {
              _showErrorDialog(message);
            } else {
              _showSuccessDialog(message);
            }
          } else {
            throw Exception(responseData['message'] ?? 'Gagal memproses data');
          }
        }
      } else {
        throw Exception('Gagal mengirim data ke server');
      }
    } catch (e) {
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pembayaran Belum Lunas'),
        content: Text(message),
        backgroundColor: Colors.red,
        contentTextStyle: const TextStyle(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hasScanned = false;
              });
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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