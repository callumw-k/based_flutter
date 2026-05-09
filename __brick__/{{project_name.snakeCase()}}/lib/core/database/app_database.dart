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
// FIRST-TIME SETUP (when introducing schemaVersion 2):
//
//   1. With schemaVersion still at 1, dump the v1 schema:
//        dart run drift_dev schema dump \
//          lib/core/database/app_database.dart drift_schemas/
//
//   2. Make your table changes, bump schemaVersion (1 -> 2), then
//      dump again so v2 also lives in drift_schemas/:
//        dart run drift_dev schema dump \
//          lib/core/database/app_database.dart drift_schemas/
//
//   3. Generate the typed step-migrations file:
//        dart run drift_dev schema steps \
//          drift_schemas/ lib/core/database/schema_versions.dart
//
//   4. Import it (`import 'schema_versions.dart';`) and replace this
//      body with:
//        return stepByStep(
//          from1To2: (m, schema) async { /* see ops below */ },
//          from2To3: (m, schema) async { ... },
//          // versions MUST be consecutive — no skipping allowed
//        )(m, from, to);
//
//   Repeat steps 2-3 every time you bump schemaVersion. Add a new
//   `fromNToN+1` callback in stepByStep each time.
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
//   - Foreign keys are enforced per-connection by the
//     `PRAGMA foreign_keys` set in beforeOpen below. stepByStep
//     auto-disables FKs during alterTable, then re-enables.
//     If you write raw `customStatement`, FK state is whatever
//     the connection currently has.
//   - `dropColumn` / `renameColumn` rely on SQLite's ALTER TABLE
//     (3.25+ / 3.35+). Old Android versions may need
//     `alterTable(TableMigration(...))` instead.
//   - Always test migrations with drift's `SchemaVerifier`
//     (drift_dev/api/migrations#testing-migrations).
//   - For destructive changes, dump and version-control the
//     drift_schemas/ JSON files — they're your only record of
//     historical schemas once code moves on.
