import 'package:drift/drift.dart' show Value;
import 'package:{{project_name.snakeCase()}}/core/database/app_database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'example_dto.freezed.dart';
part 'example_dto.g.dart';

@freezed
abstract class ExampleDto with _$ExampleDto {
  const ExampleDto._();

  const factory ExampleDto({required int id, required String name, required DateTime createdAt}) = _ExampleDto;

  ExampleCompanion toCompanion() => ExampleCompanion(id: Value(id), name: Value(name), createdAt: Value(createdAt));

  factory ExampleDto.fromJson(Map<String, Object?> json) => _$ExampleDtoFromJson(json);
}
