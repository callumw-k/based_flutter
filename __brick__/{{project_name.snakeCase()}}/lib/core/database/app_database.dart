import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:{{project_name.snakeCase()}}/features/example/data/tables/example.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Example])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'app_database'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {},
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

// -----------------------------------------------------------
// DRIFT MIGRATIONS CHEATSHEET
// Docs: https://drift.simonbinder.eu/migrations/
// -----------------------------------------------------------
//
// ADDING A NEW SCHEMA VERSION (e.g. v1 -> v2):
//
//   1. Add or modify your tables. Register any new ones in
//      @DriftDatabase(tables: [...]) and bump schemaVersion.
//      Add any imports the generated app_database.g.dart will
//      need — it's a `part of` this file and inherits imports
//      from here. Typed enum columns (textEnum<MyEnum>(),
//      intEnum<MyEnum>()) are a common case: the enum type
//      must be importable from this file.
//
//   2. Run drift_dev make-migrations. It reads build.yaml's
//      `databases:` block and, in one shot, regenerates:
//        - drift_schemas/<db>/drift_schema_v<N>.json
//          (new version dump)
//        - lib/core/database/app_database.steps.dart
//          (typed step migrations: Schema<N>, stepByStep)
//        - test/drift/<db>/migration_test.dart and
//          test/drift/<db>/generated/  (created the first time
//          any version above 1 exists; updated each run after).
//
//        dart run drift_dev make-migrations
//
//   3. One-time setup, only the first time you cross v1: update
//      this constructor to accept an optional QueryExecutor so
//      the generated migration test can open against an
//      in-memory DB:
//
//        AppDatabase([QueryExecutor? executor])
//            : super(executor ?? driftDatabase(name: 'app_database'));
//
//   4. Import the steps file and wire onUpgrade:
//
//        import 'app_database.steps.dart';
//
//        onUpgrade: stepByStep(
//          from1To2: (m, schema) async { /* see ops below */ },
//          from2To3: (m, schema) async { ... },
//          // Callbacks MUST be consecutive — no skipping allowed.
//        ),
//
//   5. Verify:
//        flutter analyze
//        flutter test test/drift/app_database/migration_test.dart
//
// -----------------------------------------------------------
// IF make-migrations REFUSES TO WRITE (mismatched older dump):
//
// make-migrations refuses to overwrite a dump that disagrees
// with the live code, and refuses to write version M when M is
// lower than the latest existing dump. To regenerate an older
// (or empty) version, replay the file's history briefly:
//
//   a. cp lib/core/database/app_database.dart /tmp/app_database_curr.dart
//   b. Revert this file to the older version's state:
//        git checkout <older-commit> -- lib/core/database/app_database.dart
//   c. Delete the conflicting dump (and any dumps for versions
//      newer than the one you're regenerating — they'll be
//      written again at step e):
//        rm drift_schemas/<db>/drift_schema_v<wrong>.json
//   d. dart run drift_dev make-migrations
//      (writes the correct older dump)
//   e. cp /tmp/app_database_curr.dart lib/core/database/app_database.dart
//   f. dart run drift_dev make-migrations
//      (regenerates newer dumps + steps file + test scaffold)
//
// -----------------------------------------------------------
// COMMON MIGRATION OPERATIONS (inside a fromXToY callback):
//
//   // Create / drop tables
//   await m.createTable(schema.users);
//   await m.deleteTable('users');     // string — table is gone from schema
//
//   // Columns
//   await m.addColumn(schema.users, schema.users.email);
//   await m.dropColumn(schema.users, 'old_field');
//   await m.renameColumn(schema.users, 'old_name', schema.users.newName);
//
//   // Rename a table
//   await m.renameTable(schema.users, 'people');
//
//   // Indexes
//   await m.createIndex(schema.usersEmailIdx);
//   await m.drop(schema.usersEmailIdx);
//
//   // Complex alterations (type change, NOT NULL change, default change,
//   // anything sqlite's ALTER TABLE can't do directly):
//   await m.alterTable(TableMigration(
//     schema.users,
//     columnTransformer: {
//       schema.users.age: schema.users.age.cast<int>(),
//     },
//     newColumns: [schema.users.createdAt],
//   ));
//
//   // Data backfills / one-off SQL (escape hatch — prefer the typed APIs):
//   await customStatement(
//     "UPDATE users SET active = 1 WHERE active IS NULL",
//   );
//
// -----------------------------------------------------------
// GOTCHAS:
//
//   - The `schema` arg in a fromXToY callback is the OLD schema
//     (the `from` version). For v1 -> v2, `schema` exposes v1's
//     tables/columns; new v2 tables/columns are referenced by
//     literal SQL or via `m.createTable(...)` against the current
//     `database.allSchemaEntities`.
//   - app_database.g.dart is a `part of` this file and so reads
//     its imports from here. Any type referenced by a column
//     (textEnum<MyEnum>(), TypeConverter<MyClass, ...>, etc.)
//     must be importable from app_database.dart, not just from
//     the table file. Missing imports surface as "Undefined name"
//     errors in the generated file.
//   - Foreign keys are enforced per-connection by the
//     `PRAGMA foreign_keys` set in beforeOpen below. stepByStep
//     auto-disables FKs during alterTable, then re-enables.
//     If you write raw `customStatement`, FK state is whatever
//     the connection currently has.
//   - `dropColumn` / `renameColumn` rely on SQLite's ALTER TABLE
//     (3.25+ / 3.35+). Old Android versions may need
//     `alterTable(TableMigration(...))` instead.
//   - The constructor's optional QueryExecutor parameter is what
//     lets drift's generated migration test instantiate
//     AppDatabase(schema.newConnection()). Don't remove it even
//     if your app code only ever calls AppDatabase().
//   - For destructive changes, version-control the
//     drift_schemas/<db>/drift_schema_v<N>.json files — they're
//     your only record of historical schemas once code moves on.
