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
    // Prevent multiple simultaneous scans
    if (_isProcessing || _hasScanned) return;

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    try {
      // Remove leading pipe if exists
      final String cleanQrData =
          qrData.startsWith('|') ? qrData.substring(1) : qrData;

      // Split the QR data
      final List<String> dataParts = cleanQrData.split('|');

      // Debug: Print total number of parts and all parts
      debugPrint('Total bagian QR Data: ${dataParts.length}');
      debugPrint('Semua bagian QR Data: $dataParts');

      // Validate QR code format
      if (dataParts.length < 20) {
        // Pastikan ada minimal 20 bagian
        throw Exception('Format QR code tidak valid');
      }

      final String id = dataParts[0].trim(); // S0001
      final String nama = dataParts[1].trim(); // Bambii
      final String statusPembayaran =
          dataParts[19].trim(); // Status pembayaran (index 19)

      // Determine if it's a teacher or student
      final bool isGuru = id.startsWith('G');

      // Prepare request body
      Map<String, dynamic> requestBody = {
        'mode': isGuru ? 'presensiGuru' : 'presensiSiswa',
        'id': id,
        'namaLengkap': nama,
        if (!isGuru) 'statusPembayaran': statusPembayaran,
      };

      // Debug print
      debugPrint('Sending request: ${jsonEncode(requestBody)}');

      // Send request to Google Apps Script
      final response = await http.post(
        Uri.parse(
            'https://script.google.com/macros/s/AKfycbxQ30OJ77ZbzVFziAaUNofRuZYy-FVK6LCAzELBwS28rJg__nKHOu9ni52HrqAUW72f/exec'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      // Debug print response
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      // Check for redirect
      if (response.statusCode == 302) {
        final String? redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final redirectResponse = await http.get(Uri.parse(redirectUrl));

          debugPrint(
              'Redirect response status: ${redirectResponse.statusCode}');
          debugPrint('Redirect response body: ${redirectResponse.body}');

          // Parse the response
          final responseData = jsonDecode(redirectResponse.body);

          // Check response status
          if (responseData['status'] == 'success') {
            // Prepare display message
            String message = isGuru
                ? 'Data Guru:\nKode: $id\nNama: $nama'
                : 'Data Siswa:\nKode: $id\nNama: $nama\nStatus Pembayaran: $statusPembayaran';

            // Add additional details from response
            if (responseData['data'] != null) {
              message +=
                  '\n\nKode Presensi: ${responseData['data']['kodePresensi']}';
              message += '\nWaktu: ${responseData['data']['timestamp']}';
            }

            // Show success dialog
            _showSuccessDialog(message);
          } else {
            // Throw error if server returns error status
            throw Exception(responseData['message'] ?? 'Gagal memproses data');
          }
        }
      } else {
        throw Exception('Gagal mengirim data ke server');
      }
    } catch (e) {
      // Show error dialog
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    } finally {
      // Reset processing state
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
                _hasScanned = false; // Reset scan status
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
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hasScanned = false; // Reset scan status
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
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
                      // Send data to server and show popup after scanning
                      _sendData(barcode.rawValue!);
                    }
                  }
                },
              ),
            ),
            if (_isProcessing)
              const CircularProgressIndicator(), // Show processing indicator
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
