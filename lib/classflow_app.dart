import 'package:flutter/material.dart';

import 'config/app_environment.dart';

class ClassFlowApp extends StatelessWidget {
  const ClassFlowApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClassFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B5B),
          surface: const Color(0xFFF8F7F2),
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_stories_outlined, size: 40),
                    const SizedBox(height: 28),
                    Text(
                      'ClassFlow',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A clear start for every class.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 36),
                    Text('Environment: ${environment.value}'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
