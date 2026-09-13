import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

import 'screens/main_screen.dart';
import 'services/favorites_service.dart';
import 'services/playlist_service.dart';
import 'services/recently_played_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    PathProviderWindows.registerWith();
    SharedPreferencesWindows.registerWith();
  }

  JustAudioMediaKit.ensureInitialized();

  await Future.wait([
    FavoritesService.instance.init(),
    RecentlyPlayedService.instance.init(),
    PlaylistService.instance.init(),
  ]);

  runApp(const SachuMusicApp());
}

class SachuMusicApp extends StatelessWidget {
  const SachuMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sachu Music',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
