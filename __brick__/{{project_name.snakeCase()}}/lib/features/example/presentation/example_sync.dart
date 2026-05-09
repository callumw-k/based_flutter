import 'package:{{project_name.snakeCase()}}/features/example/data/example_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exampleSyncProvider = AsyncNotifierProvider<ExampleSync, void>(ExampleSync.new, retry: (_, _) => null);

class ExampleSync extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    final repo = ref.watch(exampleRepositoryProvider);
    await repo.refreshAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(exampleRepositoryProvider).refreshAll());
  }
}
