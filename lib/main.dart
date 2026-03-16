import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gourmet_go_app.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  _bootstrap().then((_) {
    FlutterNativeSplash.remove();
    runApp(
      const ProviderScope(
        child: GourmetGoApp(),
      ),
    );
  });
}

Future<void> _bootstrap() async {
  await GourmetGoApp.lockToLandscape();
  await dotenv.load(fileName: '.env');
  developer.log('bootstrap complete', name: 'gourmet_go');
}
