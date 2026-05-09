import 'package:{{project_name.snakeCase()}}/core/database/app_database_provider.dart';
import 'package:{{project_name.snakeCase()}}/core/network/dio_provider.dart';
import 'package:{{project_name.snakeCase()}}/features/example/data/example_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exampleRepositoryProvider = Provider<ExampleRepository>((ref) {
  return ExampleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(dioProvider),
  );
});
