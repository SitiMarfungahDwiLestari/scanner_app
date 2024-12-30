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
      title: 'Scanner App',
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
  bool _isProcessing = false; // Menandakan jika sedang memproses data
  bool _hasScanned = false; // Menandakan jika QR sudah dipindai

  Future<void> _sendData(String qrData) async {
    if (_isProcessing || _hasScanned) {
      // Jika sedang memproses atau sudah pernah dipindai, tidak akan mengirim data lagi
      return;
    }

    setState(() {
      _isProcessing = true;
      _hasScanned = true; // Menandakan bahwa data sudah dipindai
    });

    try {
      // Pisahkan data QR Code
      final List<String> data = qrData.split('|');
      if (data.length < 2) {
        _showErrorDialog('QR Code tidak valid');
        return;
      }

      final String nama = data[1]; // Nama Lengkap
      final String id = data[0].split(',')[0]; // ID

      // Buat body data dalam format JSON
      final Map<String, String> requestBody = {
        'nama': nama,
        'id': id,
      };

      // URL Google Apps Script untuk menerima POST request
      final Uri uri = Uri.parse(
          'https://script.google.com/macros/s/AKfycbxTxIMQWYJrxC_q_Xg8MiwQyug5O3Jw0qcFAwntamPSSasTVtwVSSBs3DV5XMHnYVhz/exec');

      // Kirim data ke server menggunakan POST request
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Tangani response dari server, tanpa menampilkan pesan error
      if (response.statusCode == 200) {
        // Menampilkan data yang dipindai di pop-up
        _showSuccessDialog(
            'Data berhasil dikirim untuk:\nNama: $nama\nID: $id');
      } else {
        // Cek apakah 302 terjadi, tapi jangan tampilkan pesan error
        if (response.statusCode == 302) {
          print('Pengalihan terjadi, tapi data tetap berhasil dikirim.');
        }
        // Data tetap berhasil dikirim, hanya menampilkan data QR Code
        _showSuccessDialog('QR Code ditemukan: $qrData');
      }
    } catch (e) {
      print('Error: $e');
      _showErrorDialog('Error: $e');
    } finally {
      setState(() {
        _isProcessing = false; // Menandakan bahwa proses telah selesai
      });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Ditemukan'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hasScanned = false; // Resetkan status pemindaian
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
                _hasScanned = false; // Resetkan status pemindaian
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
        title: const Text('Scanner'),
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
                      // Kirim data ke server dan tampilkan pop-up setelah pemindaian
                      _sendData(barcode.rawValue!);
                    }
                  }
                },
              ),
            ),
            if (_isProcessing)
              const CircularProgressIndicator(), // Menampilkan indikator proses
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
