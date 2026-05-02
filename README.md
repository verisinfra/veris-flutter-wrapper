# Veris Flutter Wrapper

A community-maintained Flutter wrapper for [Veris](https://verisinfra.com) identity verification SDKs.

## Supported products

- **Veris Capture** - Face capture with passive and active liveness detection
- **Veris Scan** - Document OCR for Nigerian ID types (NIN, passport, driver's licence, PVC, utility bills) - *coming soon*

## Requirements

- Flutter >=3.x
- Android minimum SDK 21
- iOS minimum 13
- A free Veris sandbox API key - sign up at https://verisinfra.com

---

## Installation

```yaml
dependencies:
  veris_flutter: ^0.1.0
```

Then run:

```bash
flutter pub get
```

### Android

No additional setup required. Minimum SDK 21 is set automatically.

### iOS

Add camera usage description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Required for identity verification</string>
```

---

## Quick start - Veris Capture

Veris Capture handles face capture with optional liveness detection depending on your plan.

```dart
import 'package:veris_flutter/veris_flutter.dart';

// Initialise once - at app startup
await VerisCapture.init(licenseKey: 'veris_sandbox_reg_xxxx');

// Fetch a nonce from your backend before each session
final nonce = await yourBackend.fetchNonce();

// Start a capture session
final result = await VerisCapture.startCapture(nonce: nonce);

if (result.success) {
  // Send the signed payload to your backend for verification
  await yourBackend.verifyResult(result.signedPayload);
} else {
  print('Capture failed: ${result.errorMessage}');
}
```

The `signedPayload` is an ECDSA-signed JSON object. Send it to your backend and POST it to `https://api.verisinfra.com/v1/sdk/verify-result` for server-side confirmation.

### Liveness detection by plan

| Feature | Starter | Regular | Pro |
|---|---|---|---|
| Face capture + quality checks | Yes | Yes | Yes |
| Passive liveness (LBP) | - | Yes | Yes |
| Active liveness - 1 challenge | - | Yes | Yes |
| Active liveness - 2-4 challenges | - | - | Yes |
| Video capture | - | - | Yes |

On Regular and Pro plans, liveness runs automatically based on your plan flags - no extra configuration needed.

### Pro active liveness configuration

Pro plans support 2-4 independent dot-follow rounds with randomised directions:

```dart
final result = await VerisCapture.startCapture(
  nonce: nonce,
  config: VerisSessionConfig(
    proRandomChallengeCount: 3,  // 2-4 rounds, Pro only
    enforceChallenge: true,      // force active liveness even if passive passed
  ),
);
```

### Handling all result states

```dart
final result = await VerisCapture.startCapture(nonce: nonce);

switch (result.state) {
  case CaptureState.success:
    // result.signedPayload is ready to send to your backend
    await yourBackend.verifyResult(result.signedPayload);
    break;

  case CaptureState.failure:
    // User-facing message is in result.errorMessage
    // Error code for your logs is in result.errorCode
    showDialog(message: result.errorMessage);
    break;

  case CaptureState.subscriptionInactive:
    // Subscription has lapsed - prompt renewal
    showRenewalPrompt();
    break;

  case CaptureState.cancelled:
    // User dismissed the capture screen
    break;
}
```

The SDK never throws an unhandled exception into your app. It always returns one of the four states above.

---

## Backend integration - nonce flow

Each capture session requires a fresh nonce from your backend to prevent replay attacks.

**Your backend:**

```dart
// Fetch nonce before starting each session
Future<String> fetchNonce() async {
  final response = await http.post(
    Uri.parse('https://your-api.com/generate-nonce'),
  );
  return jsonDecode(response.body)['nonce'];
}
```

**Your backend server (Node.js example):**

```javascript
// Generate a UUID v4 nonce per session
app.post('/generate-nonce', async (req, res) => {
  const nonce = crypto.randomUUID();
  // Store in Redis with 10-minute TTL
  await redis.set(`nonce:${nonce}`, 'pending', 'EX', 600);
  res.json({ nonce });
});

// After SDK returns a signed payload, verify it
app.post('/verify-result', async (req, res) => {
  const { signedPayload } = req.body;
  const response = await fetch('https://api.verisinfra.com/v1/sdk/verify-result', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ signed_payload: signedPayload }),
  });
  const result = await response.json();
  res.json(result);
});
```

---

## Sandbox mode

During development, use a sandbox key. It is free and requires no KYC:

```dart
await VerisCapture.init(licenseKey: 'veris_sandbox_reg_xxxx');
```

Sandbox sessions show a small "SANDBOX" badge in the camera preview. The badge is removed automatically when you switch to a production key.

Sandbox limits:
- 50 sessions per day
- Results are marked `"environment": "sandbox"` in the signed payload
- Sandbox-signed results are rejected by the production verify endpoint

Get a free sandbox key at https://verisinfra.com.

---

## Veris Scan - coming soon

Document OCR support (NIN, passport, driver's licence, PVC, and utility bills) is in active development. Watch this repo for updates.

---

## API reference

### VerisCapture

| Method | Description |
|---|---|
| `VerisCapture.init({licenseKey})` | Initialise the SDK. Call once at startup. |
| `VerisCapture.startCapture({nonce, config})` | Launch the capture screen. Returns a `CaptureResult`. |

### VerisSessionConfig

| Parameter | Type | Default | Description |
|---|---|---|---|
| `proRandomChallengeCount` | `int` | 2 | Number of dot-follow rounds for Pro plans. Range 2-4. |
| `enforceChallenge` | `bool` | false | Force active liveness even if passive liveness already passed. |

### CaptureResult

| Field | Type | Description |
|---|---|---|
| `state` | `CaptureState` | `success`, `failure`, `subscriptionInactive`, or `cancelled` |
| `signedPayload` | `String?` | ECDSA-signed JSON. Present only on `success`. |
| `errorMessage` | `String?` | User-facing error message. Present on `failure`. |
| `errorCode` | `String?` | Machine-readable error code. Present on `failure`. |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT - see [LICENSE](LICENSE).
