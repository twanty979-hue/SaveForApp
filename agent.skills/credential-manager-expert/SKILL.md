---
name: credential-manager-expert
description: Expert on the flutter_credential_manager_compose plugin (pub.dev package "credential_manager") — Android Jetpack Credential Manager, iOS Keychain/AutoFill, Web (WebAuthn + Credential Management API + Google Identity Services/FedCM), passkeys (FIDO2/WebAuthn), password credentials, and Google Sign-In in Flutter. Use this skill whenever the user asks about implementing passkeys, biometric sign-in, password autofill, "one tap" or "one-tap" Google sign-in, Google Identity Services (GIS), FedCM, Credential Manager errors/exception codes, Digital Asset Links / assetlinks.json, Associated Domains / apple-app-site-association, Swift Package Manager vs CocoaPods for this plugin, the `<script>` tag required in `web/index.html`, or when writing/reviewing/debugging any Dart code that imports credential_manager, credential_manager_platform_interface, credential_manager_android, credential_manager_ios, or credential_manager_web. Also use it for questions phrased generically like "how do I save a login in my Flutter app" or "how do I let iOS/Android/browsers suggest a password" — those almost always mean this plugin's password-credential or passkey flow. Trigger even if the user doesn't name the package explicitly, as long as they're working in this repo or clearly building on this plugin.
---

# Credential Manager Expert

You are acting as the resident expert on `flutter_credential_manager_compose` (umbrella pub.dev package: `credential_manager`), a federated Flutter plugin that wraps Android's Jetpack Credential Manager, iOS Keychain/AutoFill, and Web's WebAuthn + Credential Management API + Google Identity Services behind one Dart API. Your job is to write, review, and debug code against the actual current API — not the plausible-sounding API an LLM might guess at. This plugin has a real history of docs drifting from code (wrong method names, wrong field nesting, invented exception classes), so treat every claim in this file as ground truth extracted directly from source, and re-verify against source if the code in this repo has moved on since.

## Package Layout
- `credential_manager_platform_interface` (Dart contracts: models, exceptions, `CredentialManagerPlatform`)
- `credential_manager_android` (Kotlin)
- `credential_manager_ios` (Swift)
- `credential_manager_web` (dart:js_interop + JS bundle)
- `credential_manager` (umbrella package — this is what apps actually import)

`credential_manager_web`'s Dart code uses `dart:js_interop`, which only resolves when compiling for the web target. `credential_manager_core.dart` therefore registers it through a conditional import (`web_registration_stub.dart` / `web_registration_web.dart`, gated on `dart.library.js_interop`) — never add a direct, unconditional import `import 'package:credential_manager_web/...'` anywhere reachable from non-web builds, or Android/iOS builds break with `'JSString' isn't a type` and similar errors.

Always import `import 'package:credential_manager/credential_manager.dart';` in application code — it re-exports everything from the platform interface (models, exceptions, `CredentialManager`).

## The Core API (Instance-Based)
`CredentialManager` (from `credential_manager_core.dart`) is an instance-based class — not static methods. There is no `CredentialManager.save(...)` static API. Always construct one:

```dart
final credentialManager = CredentialManager();

if (credentialManager.isSupportedPlatform) {   // Android || iOS || Web
  await credentialManager.init(
    preferImmediatelyAvailableCredentials: true,  // required named param
    googleClientId: '<your-web-client-id>',       // optional, only needed for Google Sign-In
  );
}

if (!credentialManager.isGmsAvailable) {
  // Android-only signal (always true on iOS/Web). False means Google Play Services is missing —
  // don't launch Google flows, you'll otherwise hit exception code 209.
}
```

`isSupportedPlatform` checks `CredentialManagerPlatformManager.instance` (`isAndroid` || `isIOS` || `isWeb`) — Web included. On Web, remember the plugin's JS bundle is not injected automatically; see the "Web setup" note below.

### Full Method Surface

| Method | Signature | Notes |
| :--- | :--- | :--- |
| `savePasswordCredentials` | `Future<void> savePasswordCredentials(PasswordCredential credential)` | Plural "Credentials". `savePasswordCredential` (singular) does not exist. Android + iOS + Web. |
| `savePasskeyCredentials` | `Future<PublicKeyCredential> savePasskeyCredentials({required CredentialCreationOptions request})` | Registers/creates a passkey. Android + iOS + Web (WebAuthn). |
| `getCredentials` | `Future<Credentials> getCredentials({CredentialLoginOptions? passKeyOption, FetchOptionsAndroid? fetchOptions})` | One entry point for reading back password, passkey, or Google credentials. On Web this tries passkey first, then Google Sign-In. |
| `saveGoogleCredential` | `Future<GoogleIdTokenCredential?> saveGoogleCredential(bool useButtonFlow, {String? nonce})` | Android + Web only (not iOS). `nonce` is optional. The umbrella wraps this with: `{bool useButtonFlow = false, String? nonce}`. |
| `logout` | `Future<void> logout()` | Android-only real effect (clears session); no-op on iOS/Web. |
| `getPlatformVersion` | `Future<String?> getPlatformVersion()` | Diagnostic only. |

**Getters**: `isSupportedPlatform` (bool), `isGmsAvailable` (bool, set during `init`).

## Web Setup
Unlike Android/iOS, `credential_manager_web` is not wired up automatically. Every app targeting Web must add this to `web/index.html`, before Flutter boots:

```html
<script src="assets/packages/credential_manager_web/web/passkey_authenticator.js"></script>
```
Without it, `init()` throws `CredentialException(code: 101, message: 'Initialization failure: JavaScript not loaded')`.

## Models
*   **`PasswordCredential`**: `username`, `password` (both `String?`, mutable getters/setters).
*   **`PublicKeyCredential` (top level)**: `id`, `rawId`, `type`, `authenticatorAttachment`, `transports` (`List<String>?`), `clientExtensionResults`, `publicKeyAlgorithm` (`int?`), `publicKey` (`String?`), and `response` (a nested `Response` object).
*   **`PublicKeyCredential.response` (nested `Response` class)**: `clientDataJSON`, `attestationObject`, `authenticatorData`, `publicKey`, `transports`, `signature`, `userHandle`.
    *   *Example*: `credential.publicKeyAlgorithm` (NOT `credential.response.publicKeyAlgorithm`), but `credential.response.clientDataJSON` (NOT `credential.clientDataJSON`).
*   **`Credentials`** (return type of `getCredentials`): a bag with three optional fields — `passwordCredential`, `publicKeyCredential`, `googleIdTokenCredential` — exactly one of which is populated depending on what was fetched.
*   **`GoogleIdTokenCredential`**: `email`, `idToken` (required), plus optional `displayName`, `familyName`, `givenName`, `phoneNumber`, `profilePictureUri`.
*   **`FetchOptionsAndroid`**: `passKey`, `googleCredential`, `passwordCredential` (all default `false` in the constructor). Android-specific; harmless but unused on iOS. Web ignores `passwordCredential`.
*   **`CredentialLoginOptions`**: `challenge` and `rpId` required, `userVerification` required, `timeout` (default 30min), `conditionalUI` (iOS-only, default `false`).
*   **`CredentialCreationOptions`**: `challenge`, `rp` (`Rp(name, id)`), `user` (`User(id, name, displayName)`), `pubKeyCredParams`, `excludeCredentials`, `authenticatorSelection`, `timeout` (default 1800000), `attestation` (default `'none'`).

## Exceptions
Only one exception type exists: `CredentialException` implements `Exception`, with `code` (int), `message` (String), `details` (dynamic). Do NOT invent subclasses like `CredentialCancelledException`.

```dart
try {
  await credentialManager.savePasswordCredentials(PasswordCredential(username: u, password: p));
} on CredentialException catch (e) {
  if (e.code == 201) {
    // user cancelled
  } else {
    // real failure
  }
}
```
*Common Codes*: `201` (user cancelled), `202` (no credentials found), `207` (no Google account), `209` (Google Play Services unavailable), `601`–`603` (passkey failures).

## Platform Support Matrix
*   **Passwords**: Android + iOS + Web (save-only on Web).
*   **Passkeys**: Android 14+ and iOS 16+ on native; Web works on any WebAuthn-capable browser.
*   **Google Sign-In**: Android + Web. Not supported on iOS.

## Native Configuration Files
When you need native setup details, read the relevant reference files:
- Android (proguard, `assetlinks.json`): `references/android-setup.md`
- iOS (Associated Domains, `apple-app-site-association`): `references/ios-setup.md`
- Web (OAuth setup, authorized JavaScript origins): `references/web-setup.md`
- API Reference (JSON models, WebAuthn shapes): `references/api-reference.md`
- Exception Troubleshooting: `references/troubleshooting.md`

## Versioning Convention
This repo uses a specific versioning scheme:
- Bug fix or small change: **Minor** bump.
- Migration, new feature, or breaking change: **Major** bump.
- Do NOT correct this to standard semver.
