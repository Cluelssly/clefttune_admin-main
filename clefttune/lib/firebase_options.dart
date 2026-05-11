import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default FirebaseOptions for CleftTune Admin Dashboard
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;

      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS is not configured yet.',
        );

      case TargetPlatform.macOS:
        throw UnsupportedError(
          'macOS is not configured yet.',
        );

      case TargetPlatform.windows:
        throw UnsupportedError(
          'Windows is not configured yet.',
        );

      case TargetPlatform.linux:
        throw UnsupportedError(
          'Linux is not configured yet.',
        );

      default:
        throw UnsupportedError(
          'This platform is not supported.',
        );
    }
  }

  /// WEB FIREBASE CONFIG
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCBygrUN1Dq1iVh1hcO0RcdC6Lt2CtPxDs',
    appId: '1:756813986418:web:68a043e4f9a286037620eb',
    messagingSenderId: '756813986418',
    projectId: 'appcleft2026-55337',
    authDomain: 'appcleft2026-55337.firebaseapp.com',
    storageBucket: 'appcleft2026-55337.firebasestorage.app',
    measurementId: 'G-08JMBP64EL',
  );

  /// ANDROID FIREBASE CONFIG
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD9lgM6F2qU5oMBytqy_H-I0tXn1nIE8SY',
    appId: '1:756813986418:android:edc4e7239da11cd07620eb',
    messagingSenderId: '756813986418',
    projectId: 'appcleft2026-55337',
    storageBucket: 'appcleft2026-55337.firebasestorage.app',
  );
}