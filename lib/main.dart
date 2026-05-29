import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/recorder/presentation/recorder_screen.dart';
import 'services/metadata_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MetadataService().init();
  runApp(const ProviderScope(child: EchoRecorderApp()));
}

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class EchoRecorderApp extends StatelessWidget {
  const EchoRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoRecorder',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const RecorderScreen(),
    );
  }
}
