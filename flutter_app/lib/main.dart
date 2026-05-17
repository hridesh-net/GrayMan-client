import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/grayman_app.dart';
import 'core/design_system/app_theme.dart';
import 'core/networking/token_store.dart';
import 'core/location/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await TokenStore.instance.load();
  await LocationService.instance.requestPermission();
  final theme = GrayManTheme();
  await theme.load();
  runApp(
    ChangeNotifierProvider<GrayManTheme>.value(
      value: theme,
      child: const GrayManAppRoot(),
    ),
  );
}

class GrayManAppRoot extends StatelessWidget {
  const GrayManAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return MaterialApp(
      title: 'sthapna.ai',
      debugShowCheckedModeBanner: false,
      theme: theme.materialTheme,
      home: const GrayManApp(),
    );
  }
}
