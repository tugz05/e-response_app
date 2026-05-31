/// Google Sign-In: **Web application** OAuth 2.0 client ID from
/// [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
///
/// On **Android**, if this is empty, the plugin uses `default_web_client_id` in
/// `android/app/src/main/res/values/strings.xml` (required unless you use
/// `google-services.json` with a web `oauth_client`).
///
/// Set via `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`, [_embeddedServerClientId],
/// or the Android string — Laravel should verify `id_token` `aud` against this Web client.
class GoogleSignInConfig {
  GoogleSignInConfig._();

  static const String _embeddedServerClientId =
      '490198227720-9ld91f0ggs9g70bjgcd1h8j8t2h5ii6n.apps.googleusercontent.com';

  static String get serverClientId {
    const fromEnv = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    );
    return fromEnv.isNotEmpty ? fromEnv : _embeddedServerClientId;
  }
}
