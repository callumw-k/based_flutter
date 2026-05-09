import 'package:{{project_name.snakeCase()}}/core/database/app_database.dart';
import 'package:{{project_name.snakeCase()}}/features/example/data/example_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exampleListProvider = StreamProvider.autoDispose<List<ExampleData>>((ref) {
  return ref.watch(exampleRepositoryProvider).watchAll();
});
