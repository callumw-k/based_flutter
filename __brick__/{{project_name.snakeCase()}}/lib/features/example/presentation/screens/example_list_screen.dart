import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_controller.dart';
import 'package:{{project_name.snakeCase()}}/core/logging/talker.dart';
import 'package:{{project_name.snakeCase()}}/core/router/app_router.dart';
import 'package:{{project_name.snakeCase()}}/features/example/presentation/example_list.dart';
import 'package:{{project_name.snakeCase()}}/features/example/presentation/example_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class ExampleListScreen extends ConsumerWidget {
  const ExampleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(exampleSyncProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: ${next.error}'),
            action: SnackBarAction(label: 'Retry', onPressed: () => ref.read(exampleSyncProvider.notifier).refresh()),
          ),
        );
      }
    });

    final list = ref.watch(exampleListProvider);
    final sync = ref.watch(exampleSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Examples'),
        actions: [
          IconButton(
            icon: sync.isLoading
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: sync.isLoading ? null : () => ref.read(exampleSyncProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Open log viewer',
            onPressed: () => context.router.push(const LogViewerRoute()),
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.timer_off),
              tooltip: 'Simulate session eviction',
              onPressed: () => ref.read(authControllerProvider.notifier).evict(),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: () => talker.info('Test info log'), child: const Text('info')),
                OutlinedButton(onPressed: () => talker.debug('Test debug log'), child: const Text('debug')),
                OutlinedButton(
                  onPressed: () => talker.error('Test error log', Exception('Demo exception'), StackTrace.current),
                  child: const Text('error'),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.when(
              data: (rows) => rows.isEmpty
                  ? const Center(child: Text('No examples yet.'))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) =>
                          ListTile(title: Text(rows[i].name), subtitle: Text(rows[i].createdAt.toString())),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
