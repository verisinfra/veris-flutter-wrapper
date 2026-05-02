import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ignore: depend_on_referenced_packages
import 'package:veris_flutter/veris_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Veris Capture once at startup.
  // Replace with your sandbox key from https://verisinfra.com
  await VerisCapture.init(licenseKey: 'veris_sandbox_reg_xxxx');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Veris Example',
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _status = 'Ready';

  // -------------------------------------------------------------------
  // Fetch a nonce from your backend before each session.
  // Replace the URL with your own nonce endpoint.
  // -------------------------------------------------------------------
  Future<String> _fetchNonce() async {
    final response = await http.post(
      Uri.parse('https://your-api.com/generate-nonce'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch nonce');
    }
    return jsonDecode(response.body)['nonce'] as String;
  }

  // -------------------------------------------------------------------
  // Send the signed payload to your backend, which forwards it to
  // POST https://api.verisinfra.com/v1/sdk/verify-result
  // -------------------------------------------------------------------
  Future<void> _verifyWithBackend(String signedPayload) async {
    final response = await http.post(
      Uri.parse('https://your-api.com/verify-result'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'signed_payload': signedPayload}),
    );
    if (response.statusCode == 200) {
      setState(() => _status = 'Verified successfully');
    } else {
      setState(() => _status = 'Verification failed: ${response.body}');
    }
  }

  // -------------------------------------------------------------------
  // Veris Capture - face capture with liveness detection
  // -------------------------------------------------------------------
  Future<void> _startCapture() async {
    setState(() => _status = 'Fetching nonce...');

    try {
      final nonce = await _fetchNonce();

      setState(() => _status = 'Starting capture...');

      final result = await VerisCapture.startCapture(nonce: nonce);

      switch (result.state) {
        case CaptureState.success:
          setState(() => _status = 'Capture succeeded - verifying...');
          await _verifyWithBackend(result.signedPayload!);

        case CaptureState.failure:
          setState(() => _status = 'Capture failed: ${result.errorMessage}');

        case CaptureState.subscriptionInactive:
          setState(() => _status = 'Subscription inactive - renew at verisinfra.com');

        case CaptureState.cancelled:
          setState(() => _status = 'Cancelled');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  // -------------------------------------------------------------------
  // Veris Capture with Pro active liveness config (2-4 challenges)
  // -------------------------------------------------------------------
  Future<void> _startCaptureWithConfig() async {
    setState(() => _status = 'Fetching nonce...');

    try {
      final nonce = await _fetchNonce();

      setState(() => _status = 'Starting Pro capture...');

      final result = await VerisCapture.startCapture(
        nonce: nonce,
        config: VerisSessionConfig(
          proRandomChallengeCount: 3, // 2-4 rounds, Pro plan only
          enforceChallenge: true,
        ),
      );

      switch (result.state) {
        case CaptureState.success:
          setState(() => _status = 'Pro capture succeeded');
          print('Signed payload: ${result.signedPayload}');

        case CaptureState.failure:
          setState(() => _status = 'Capture failed: ${result.errorMessage}');

        case CaptureState.subscriptionInactive:
          setState(() => _status = 'Subscription inactive');

        case CaptureState.cancelled:
          setState(() => _status = 'Cancelled');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  // -------------------------------------------------------------------
  // Veris Scan - document OCR (coming soon)
  // -------------------------------------------------------------------
  Future<void> _startScan() async {
    setState(() => _status = 'Veris Scan is coming soon');
    // When available:
    //
    // final result = await VerisScan.startCapture(
    //   documentType: DocumentType.driversLicence,
    // );
    // if (result.success) {
    //   print('Name: ${result.fields?.firstName} ${result.fields?.surname}');
    //   print('Face image: ${result.faceImageBase64}');
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veris Example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status: $_status', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _startCapture,
              child: const Text('Start Capture'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _startCaptureWithConfig,
              child: const Text('Start Capture (Pro config)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _startScan,
              child: const Text('Start Scan (coming soon)'),
            ),
          ],
        ),
      ),
    );
  }
}
