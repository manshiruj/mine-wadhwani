import 'package:flutter/material.dart';
import 'package:mine_wadhwani/app.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart' as di;
import 'package:mine_wadhwani/core/network/outbox.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
    await di.init();
  di.sl<Outbox>().start(); // replay inspections saved while offline
  runApp(const App());
}
