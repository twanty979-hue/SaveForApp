import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgIIHCfLd7SdMt_mdbZSKEgDYB8RvNOgw',
    appId: '1:1083007887368:android:fbb1121294ad9083fd09bd',
    messagingSenderId: '1083007887368',
    projectId: 'saveforapp',
    storageBucket: 'saveforapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAZEVNYHTUrnNmWTXZSzuCF_Gb7bRb5NTc',
    appId: '1:1083007887368:ios:15e8d745527b42a9fd09bd',
    messagingSenderId: '1083007887368',
    projectId: 'saveforapp',
    storageBucket: 'saveforapp.firebasestorage.app',
    iosBundleId: 'com.savefor.app',
  );
}
