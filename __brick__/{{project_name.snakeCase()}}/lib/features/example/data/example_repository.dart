import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:{{project_name.snakeCase()}}/core/database/app_database.dart';
import 'package:{{project_name.snakeCase()}}/core/errors/api_exception.dart';
import 'package:{{project_name.snakeCase()}}/features/example/data/models/example_dto.dart';

class ExampleRepository {
  ExampleRepository(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

  Stream<List<ExampleData>> watchAll() {
    return _db.select(_db.example).watch();
  }

  Future<ExampleData?> getById(int id) {
    return (_db.select(_db.example)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> create({required String name}) {
    return _db.into(_db.example).insert(ExampleCompanion.insert(name: name));
  }

  Future<int> updateName(int id, String name) {
    return (_db.update(_db.example)..where((t) => t.id.equals(id))).write(ExampleCompanion(name: Value(name)));
  }

  Future<int> deleteById(int id) {
    return (_db.delete(_db.example)..where((t) => t.id.equals(id))).go();
  }

  Future<void> refreshAll() async {
    final List<ExampleDto> dtos;
    try {
      final response = await _dio.get<List<dynamic>>('/examples');
      dtos = (response.data ?? const []).map((j) => ExampleDto.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw e.toApiException();
    }

    await _db.batch((b) {
      b.deleteAll(_db.example);
      b.insertAll(_db.example, dtos.map((d) => d.toCompanion()).toList());
    });
  }
}
