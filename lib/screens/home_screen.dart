import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/practice_controller.dart';
import 'dashboard_screen.dart';
import 'practice_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bankAsync = ref.watch(questionBankProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SHSAT Tutor')),
      body: Center(
        child: bankAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load questions: $err'),
          ),
          data: (bank) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PracticeScreen()),
                    ),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Start Practicing'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 240,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    ),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('View Dashboard'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
