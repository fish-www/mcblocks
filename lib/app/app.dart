import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class McBlocksApp extends StatelessWidget {
  const McBlocksApp({super.key});

  static final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'mcblocks',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: _router,
    );
  }
}
