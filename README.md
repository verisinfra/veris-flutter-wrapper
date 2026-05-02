[![CI](https://github.com/Veris-Lab/veris-flutter-wrapper/actions/workflows/ci.yml/badge.svg)](https://github.com/Veris-Lab/veris-flutter-wrapper/actions/workflows/ci.yml)
[![veris_capture on pub.dev](https://img.shields.io/pub/v/veris_capture.svg?label=veris_capture)](https://pub.dev/packages/veris_capture)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

# Veris Flutter Wrapper

Flutter integration guide and examples for [Veris](https://verisinfra.com) identity verification.

Uses the official [`veris_capture`](https://pub.dev/packages/veris_capture) package published on pub.dev.

## Supported products

- **Veris Capture** - Face capture with passive and active liveness detection
- **Veris Scan** - Document OCR for Nigerian ID types - coming soon

## Requirements

- Flutter >=3.10.0
- Dart >=3.0.0
- Android minimum SDK 24
- iOS minimum 15.0
- A free Veris sandbox key - sign up at https://verisinfra.com

---

## Installation

```yaml
dependencies:
  veris_capture: ^1.0.0
```

```bash
flutter pub get
```

### Android

No additional setup required.

### iOS

Add camera usage description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Required for identity verification</string>
```

---

## Quick start - Veris Capture

```dart
import 'package:veris_capture/veris_capture.dart';

// Initialise once at startup
await VerisCapture.init(licenseKey: 'veris_sandbox_reg_xxxx');

// Fetch a nonce from your backend before each session
final nonce = await yourBackend.fetchNonce();

// Start capture
final result = await VerisCapture.startCapture(nonce: nonce);

if (result.success) {
  await yourBackend.verifyResult(result.signedPayload);
}
```

### Handle all result states

```dart
final result = await VerisCapture.startCapture(nonce: nonce);

switch (result.state) {
  case CaptureState.success:
    await yourBackend.verifyResult(result.signedPayload!);

  case CaptureState.failure:
    showDialog(message: result.errorMessage);

  case CaptureState.subscriptionInactive:
    showRenewalPrompt();

  case CaptureState.cancelled:
    break;
}
```

The SDK never throws an unhandled exception. It always returns one of these four states.

### Liveness detection by plan

| Feature | Starter | Regular | Pro |
|---|---|---|---|
| Face capture + quality checks | Yes | Yes | Yes |
| Passive liveness | - | Yes | Yes |
| Active liveness - 1 challenge | - | Yes | Yes |
| Active liveness - 2-4 challenges | - | - | Yes |
| Video capture | - | - | Yes |

Liveness runs automatically based on your plan - no extra configuration needed.

### Pro active liveness configuration

```dart
final result = await VerisCapture.startCapture(
  nonce: nonce,
  config: VerisSessionConfig(
    proRandomChallengeCount: 3,  // 2-4 rounds, Pro only
    enforceChallenge: true,      // force active liveness even if passive passed
  ),
);
```

---

## Nonce flow (replay attack protection)

Generate a nonce on your backend before each session and pass it to the SDK.

**Your backend:**

```javascript
// Node.js - generate nonce and store in Redis
app.post('/generate-nonce', async (req, res) => {
  const nonce = crypto.randomUUID();
  await redis.set(`nonce:${nonce}`, 'pending', 'EX', 600);
  res.json({ nonce });
});
```

**Your Flutter app:**

```dart
Future<String> fetchNonce() async {
  final response = await http.post(Uri.parse('https://your-api.com/generate-nonce'));
  return jsonDecode(response.body)['nonce'] as String;
}
```

**After capture, verify the signed payload:**

```javascript
// Node.js - forward to Veris verify endpoint
app.post('/verify-result', async (req, res) => {
  const response = await fetch('https://api.verisinfra.com/v1/sdk/verify-result', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ signed_payload: req.body.signedPayload }),
  });
  res.json(await response.json());
});
```

---

## Sandbox mode

Use a sandbox key during development. Free, no payment required:

```dart
await VerisCapture.init(licenseKey: 'veris_sandbox_reg_xxxx');
```

The SDK shows a small "SANDBOX" badge in the camera preview. It disappears automatically when you switch to a production key.

Limits: 50 sessions per day. Results are marked `"environment": "sandbox"`.

---

## Veris Scan - coming soon

Document OCR (NIN, passport, driver's licence, PVC, utility bills) is in active development. Watch this repo for updates.

---

## API reference

### VerisCapture

| Method | Description |
|---|---|
| `VerisCapture.init({licenseKey})` | Initialise. Call once at startup. |
| `VerisCapture.startCapture({nonce, config})` | Launch capture screen. Returns `CaptureResult`. |

### VerisSessionConfig

| Parameter | Type | Default | Description |
|---|---|---|---|
| `proRandomChallengeCount` | `int` | 2 | Dot-follow rounds for Pro plans. Range 2-4. |
| `enforceChallenge` | `bool` | false | Force active liveness even if passive passed. |

### CaptureResult

| Field | Type | Description |
|---|---|---|
| `state` | `CaptureState` | `success`, `failure`, `subscriptionInactive`, or `cancelled` |
| `signedPayload` | `String?` | ECDSA-signed JSON. Present on `success`. |
| `errorMessage` | `String?` | User-facing error. Present on `failure`. |
| `errorCode` | `String?` | Machine-readable error code. Present on `failure`. |

---

## Example app

See [`example/lib/main.dart`](example/lib/main.dart) for a complete working example.

## Documentation

Full docs at [verisinfra.com/docs](https://verisinfra.com/docs)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT - see [LICENSE](LICENSE).
