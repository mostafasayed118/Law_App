import 'package:flutter/material.dart';

import 'app/service_locator.dart';

void main() {
  // Bootstrap spec §4.5: register dependencies once during startup.
  // B3 registers only the sample service; the UI remains a blank scaffold.
  configureDependencies();
  runApp(const LegalHubApp());
}

class LegalHubApp extends StatelessWidget {
  const LegalHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold());
  }
}
