# Template Foundations

Architectural reference for this project's foundations: the choices made and why. Each section captures one concern (state management, networking, error model, theming, etc.) and the rationale behind it.

---

## Decided foundations

### Stack (locked in)

| Concern | Choice | Notes |
|---|---|---|
| State management & DI | **Riverpod 3** (hand-written providers) | Single source of DI — no separate container. Codegen (`riverpod_generator` 4.x) was tried and dropped — see "Riverpod providers" below. |
| Routing | **auto_route** | Chosen for typed nested routes via codegen. (go_router considered; not picked.) |
| HTTP | **dio** | |
| Local database | **drift** | |
| Logging | **talker** (`talker_flutter` + `talker_dio_logger` + `talker_riverpod_logger`) | Single sink for framework errors, uncaught zone errors, provider lifecycle, and Dio request/response. |
| Theming | **flex_seed_scheme** | Better seeded `ColorScheme` generation than vanilla M3, without committing the whole theme architecture to a third-party API. `flex_color_scheme` (the larger sibling) was considered but rejected as too much dependency lock-in for a long-lived template. |

**Explicitly dropped:** `get_it`, `injectable`. Riverpod's providers cover DI with stronger ergonomics (scope-based test overrides, no global registry to reset, type safety). Stacking both was duplicative and added another `build_runner` step for no real gain.

### Project structure

**Feature-first** layout. `data/` + `presentation/` per feature. **No `domain/` layer.**

```
lib/
  core/           # shared infrastructure (Dio, Drift, router, theme, logging, etc.)
  features/
    <feature>/
      data/         # repositories, drift tables (per-feature), DTOs/models (freezed)
      presentation/ # widgets, notifiers, screens
  bootstrap.dart
  main.dart
  app.dart
```

**Rationale for skipping `domain/`:**
- Riverpod overrides give us testability without abstract repo interfaces.
- `freezed` models can cross the data ↔ presentation line directly — no need for parallel "entity" types.
- Use cases are typically 3-line passthroughs to repositories — pure ceremony.

### App entrypoint — Bootstrap pattern

Three files, three responsibilities:

- `main.dart` — single line; hands a widget builder to `bootstrap()`.
- `bootstrap.dart` — global concerns: error handlers, logging init, binding initialisation, async pre-app setup, `ProviderScope`.
- `app.dart` — root `MaterialApp.router`: theme, router, locale.

**Current `bootstrap.dart` (in `lib/bootstrap.dart`):**

```dart
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:{{project_name.snakeCase()}}/core/logging/talker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    talker.handle(details.exception, details.stack, details.summary.toString());
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    talker.handle(error, stack);
    return true;
  };

  runApp(
    ProviderScope(
      observers: [TalkerRiverpodObserver(talker: talker)],
      child: builder(),
    ),
  );
}
```

**Error capture strategy.** Uses `FlutterError.onError` (sync errors during build/layout/paint) plus `PlatformDispatcher.instance.onError` (uncaught async errors). Skipped `runZonedGuarded` — it's largely redundant since Flutter 3.3 and adds complexity. Re-add only if a downstream integration (e.g. Sentry, Crashlytics) requires a custom Zone.

**Pending additions** (each waits until its dependency lands):

- Async pre-app setup (e.g. opening the Drift database, restoring auth) — slot in before `runApp`.

**Current `main.dart`:**

```dart
import 'app.dart';
import 'bootstrap.dart';

void main() => bootstrap(() => const App());
```

**Current `app.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:{{project_name.snakeCase()}}/core/router/app_router_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final _routerConfig = ref.read(appRouterProvider).config();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _routerConfig,
    );
  }
}
```

Flavour-aware entrypoints (`main_dev.dart`, `main_prod.dart`, etc.) are a deliberate next step, not a default.

### Riverpod providers

**All providers are hand-written.** `riverpod_generator` was tried (4.x) and dropped because (a) it has a known bug emitting code for return types containing drift's auto-generated `*Data` row classes (`InvalidTypeException`), forcing per-file workarounds, and (b) hand-written providers are arguably cleaner anyway: lifecycle is explicit at the call site (`Provider` vs `Provider.autoDispose`), no `.g.dart` files to mentally filter, fewer dependencies, and the underlying provider primitive is visible. The only meaningful codegen win — terse family-parameter syntax — is rare and easy to live without. If `riverpod_generator` later fixes the bug and you want to reach for it for a specific provider, nothing prevents mixing.

**Default to `Provider<T>(...)` and friends, keep-alive by default.** Add `.autoDispose` (or use `AutoDispose*Notifier` base classes) only when the resource genuinely should die when no listeners remain.

**Lifecycle pairing reference:**

| Notifier base class | Provider constructor | Lifecycle |
|---|---|---|
| (no notifier — function provider) | `Provider<T>(...)` | keep-alive |
| (no notifier — function provider) | `Provider.autoDispose<T>(...)` | auto-dispose |
| `Notifier<T>` | `NotifierProvider<N, T>(N.new)` | keep-alive |
| `AutoDisposeNotifier<T>` | `NotifierProvider.autoDispose<N, T>(N.new)` | auto-dispose |
| `AsyncNotifier<T>` | `AsyncNotifierProvider<N, T>(N.new)` | keep-alive |
| `AutoDisposeAsyncNotifier<T>` | `AsyncNotifierProvider.autoDispose<N, T>(N.new)` | auto-dispose |
| `StreamNotifier<T>` | `StreamNotifierProvider<N, T>(N.new)` | keep-alive |
| `AutoDisposeStreamNotifier<T>` | `StreamNotifierProvider.autoDispose<N, T>(N.new)` | auto-dispose |

**Lifecycle decisions for this template:**

| Layer | Default | Reason |
|---|---|---|
| Infrastructure (Dio, AppDatabase, SharedPreferences) | keep-alive (`Provider<T>(...)`) | Expensive to construct; intentionally process-wide. Auto-disposing reopens DB connections, redoes interceptor setup. |
| Repositories | keep-alive (`Provider<T>(...)`) | Stateless and cheap, but recreating them buys nothing — keep-alive matches the surrounding "infrastructure" feel. |
| Feature state (notifiers) | auto-dispose (`*NotifierProvider.autoDispose` / `AutoDispose*Notifier`) | The whole point of Riverpod's caching — long-lived feature state is a smell. |
| Conditional caching ("alive once loaded") | auto-dispose + `ref.keepAlive()` inside the build | Riverpod 3 idiom for upgrading lifecycle on success. Returns a `KeepAliveLink` you can later `.close()`. |

**Heuristic:** if auto-disposing breaks something *real* (reopened connections, lost in-flight work, re-init of expensive interceptors), keep alive. If it just means slightly more allocation, auto-dispose.

**Auto-retry on async providers (Riverpod 3 default).** Async providers (`FutureProvider`, `StreamProvider`, `AsyncNotifierProvider`) ship with a default exponential-backoff retry policy — failures don't stick, the build is silently re-attempted. For "sync trigger" notifiers (one-shot fetch, user-driven retry via UI button), this is almost always wrong: the user sees a snackbar, taps Retry, and Riverpod was already retrying behind their back. Disable per-provider with `retry: (_, _) => null`:

```dart
final exampleSyncProvider = AsyncNotifierProvider<ExampleSync, void>(
  ExampleSync.new,
  retry: (_, _) => null,
);
```

Keep the default for providers where transparent retry makes sense (e.g. a polling stream against a flaky endpoint). Don't disable globally on `ProviderScope` — it hides the feature from providers that legitimately want it.

### Theming

`flex_seed_scheme` generates the `ColorScheme`; `ThemeData` is otherwise vanilla. Both light and dark are wired, with `ThemeMode.system` selecting between them.

**Current `lib/core/theme/app_theme.dart`:**

```dart
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color _primary = Color(0xFF401596);
  static const Color _secondary = Color(0xFF625B71);
  static const Color _tertiary = Color(0xFF7D5260);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = SeedColorScheme.fromSeeds(
      brightness: brightness,
      primaryKey: _primary,
      secondaryKey: _secondary,
      tertiaryKey: _tertiary,
      tones: FlexTones.vivid(brightness),
    );
    return ThemeData(
      colorScheme: scheme,
      pageTransitionsTheme: _pageTransitionsTheme,
    );
  }

  static const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
```

`FlexTones.vivid` is used to produce a more saturated mapping than the default M3 tones — adjust to `.material`, `.jolly`, `.candyPop`, etc. per project taste.

**Page transitions follow Material 3 / platform conventions.** `pageTransitionsTheme` supplies `FadeForwardsPageTransitionsBuilder` (the M3-spec fade-forwards motion) on Android and `CupertinoPageTransitionsBuilder` (slide + swipe-back) on iOS. Flutter's default `PageTransitionsTheme` still ships with the older M2-style transitions on Android, which look dated against an M3 colour scheme — overriding here brings motion in line with everything else from the seed scheme. The pair complements `RouteType.adaptive()` on `AppRouter`: the router decides whether a route is Material- or Cupertino-presented, and `pageTransitionsTheme` shapes the Material side. Other platforms (macOS/Windows/Linux) fall through to Flutter defaults — extend the map when those become real targets.

**Conventions and pending additions:**

- Seed colours are hex constants (`_primary`, `_secondary`, `_tertiary`). Adjust to taste per project.
- `errorKey` is not set — `SeedColorScheme.fromSeeds` falls back to a sensible default. Add an explicit error key only when brand requires it.
- No component sub-themes (`AppBarTheme`, `CardTheme`, `InputDecorationTheme`) yet — add per concrete need rather than upfront. `app_theme.dart` carries an inline example showing the convention: private helper methods on `AppTheme` (e.g. `_filledButtonTheme(ColorScheme scheme)`) slotted into the `ThemeData(...)` constructor in `_build`. Once the file accumulates many helpers (~8+), split to per-component files under `lib/core/theme/components/`.
- `app_colors.dart` (semantic tokens like `success`/`warning`) and `app_typography.dart` are deferred until a real screen needs them.
- Theme-mode persistence (e.g. user-toggleable light/dark) is deferred — currently follows OS via `ThemeMode.system`.
- `SystemUiOverlayStyle` / edge-to-edge configuration is deferred. Flutter's defaults plus `AppBar`'s automatic overlay style are sufficient until a real screen breaks under them (custom background, fullscreen hero, no AppBar). When wired, the pattern is: global `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` + transparent overlay in `bootstrap`, plus `AppBarTheme.systemOverlayStyle` per brightness in `_build`.
- A `BuildContext` extension (`context.colors`, `context.textTheme`) can be added later in `lib/core/extensions/` once enough call sites justify it.

### Environment configuration

Environment values come from compile-time constants via `--dart-define` or `--dart-define-from-file`. No runtime asset loading, no third-party package, no risk of bundling a `.env` into the app archive.

A typed wrapper consolidates env reads in one place so consumers never call `String.fromEnvironment` directly:

```dart
// lib/core/env/env.dart
class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
}
```

Run with values supplied either as individual flags:
```
flutter run --dart-define=API_BASE_URL=https://api.example.com
```
or via JSON file:
```
flutter run --dart-define-from-file=env/dev.json
```

Per-environment JSON files (`env/dev.json`, `env/staging.json`, `env/prod.json`) are added when a project actually has multiple environments — not pre-scaffolded.

### Networking — Dio provider

Dio lives behind a keep-alive `Provider`, configured from `Env`. Canonical "infrastructure singleton via Riverpod" pattern — hand-written, no codegen.

```dart
// lib/core/network/dio_provider.dart
import 'package:dio/dio.dart';
import 'package:{{project_name.snakeCase()}}/core/env/env.dart';
import 'package:{{project_name.snakeCase()}}/core/logging/talker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.add(
    TalkerDioLogger(
      talker: talker,
      settings: const TalkerDioLoggerSettings(
        printErrorMessage: true,
        printErrorData: true,
        printRequestHeaders: kDebugMode,
        printResponseHeaders: kDebugMode,
        printRequestData: kDebugMode,
        printResponseData: kDebugMode,
        printResponseMessage: kDebugMode,
        printErrorHeaders: kDebugMode,
      ),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
```

`Provider`'s default constructor is keep-alive — matches "infrastructure singleton" lifecycle. `TalkerDioLogger` is wired inline for now; if/when more interceptors land, extract them to `lib/core/network/interceptors/` and add via `dio.interceptors.addAll([...])`. No `build_runner` step needed for Riverpod itself; only `freezed`, `json_serializable`, and `drift_dev` consumers still require codegen.

**Logger verbosity is gated by `kDebugMode`.** In debug builds everything logs (headers, request bodies, response bodies, response messages). In release builds only `printErrorMessage` and `printErrorData` remain on, plus the always-on request URL line. Rationale: error status + error body are diagnostic gold even in production (helps reproduce bugs from user-uploaded logs) and rarely contain auth tokens; everything else can leak. If a real production deployment needs to redact specific fields (e.g. mask Authorization headers in dev too), use `TalkerDioLoggerSettings(requestFilter: ...)` / `responseFilter: ...`.

**Pending additions** (added when concretely needed):

- Auth-token interceptor once auth exists.
- Retry interceptor (transient 5xx + timeouts) — separate concern from translation, deferred until first real flake bites.
- Request cancellation pattern (`CancelToken` attached via `ref.onDispose`).

### Error model — typed `ApiException`

Repositories and notifiers throw a sealed `ApiException` rather than `DioException` or raw strings. Consumers (UI, sync providers, route guards) branch on the subtype to drive UX — offline banner for `NetworkException`, sign-in redirect for `AuthException`, inline field errors for `ValidationException`, retry CTA for `ServerException`.

**`lib/core/errors/api_exception.dart`:**

```dart
sealed class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.cause, this.stackTrace});

  final String message;
  final int? statusCode;
  final Object? cause;
  final StackTrace? stackTrace;
}

final class NetworkException extends ApiException { ... }    // timeouts, connection failures, bad cert
final class AuthException extends ApiException { ... }        // 401, 403
final class ValidationException extends ApiException { ... }  // 422 (with optional fieldErrors map)
final class ServerException extends ApiException { ... }      // 5xx
final class UnknownException extends ApiException { ... }     // fallback / cancellations / unclassified
```

`sealed` ensures the consumer's `switch` is exhaustive — adding a new subtype later forces every consumer to handle it.

**Translation is a `DioException` extension, not an interceptor.** `lib/core/errors/api_exception.dart` ships a `DioExceptionToApi` extension that maps `DioException` → `ApiException` based on `DioExceptionType` and HTTP status. Repositories invoke it explicitly at the Dio boundary:

```dart
Future<void> refreshAll() async {
  try {
    final response = await _dio.get<List<dynamic>>('/examples');
    // ...
  } on DioException catch (e) {
    throw e.toApiException();
  }
}
```

**Why an extension and not an interceptor.** An earlier iteration translated inside a Dio interceptor that wrapped the typed exception inside another `DioException` (`error: apiException`), then a repo-side extension unwrapped it. That worked but added a wrap-then-unwrap round trip for no real benefit — the extension call site is identical either way, and removing the interceptor avoids interaction puzzles around Dio's error chain (registration order, `handler.reject()` short-circuiting `TalkerDioLogger`). Translation runs because the repo asked for it, not because Dio invisibly tagged the error.

**Why this shape:**

- **Sealed + named subtypes over a single typed enum** — switching on `is ValidationException` lets each branch destructure the fields it needs (e.g. `fieldErrors`); a flat enum can't carry per-variant data without an awkward sidecar.
- **`fieldErrors` shape (`Map<String, List<String>>?`)** — common Laravel/Django/Rails convention for 422 bodies. The extractor is permissive: missing `errors` key → `null`, scalar values coerced to single-element lists.
- **Three lines of boilerplate per Dio-touching repo method** — the explicit `try/on DioException/throw e.toApiException()` at each Dio call site is the price for making the typed-error contract exist at the repo's public surface. Acceptable for the value it buys when consumers branch on subtype.

**Repositories don't catch what they can't handle.** Other database/parsing exceptions bubble unchanged — `AsyncValue.guard` and the bootstrap-level error handlers will catch them. Only the `DioException` boundary needs translation.

**Pending additions** (added when concretely needed):

- `DatabaseException` sealed hierarchy if drift errors start needing UX-level distinction (constraint violation vs. disk full vs. corrupted DB). For now, drift's exceptions bubble as-is.
- Per-error-type UI patterns — offline banner, sign-in redirect, retry CTA. Wired into screens once auth and routing exist.

### Logging — Talker

`talker` is the single sink for all logs across the app: framework errors, uncaught zone errors, provider lifecycle, and Dio request/response. Three integrations are wired:

- **`FlutterError.onError`** + **`PlatformDispatcher.instance.onError`** call `talker.handle(...)` from `bootstrap.dart`, replacing the earlier `debugPrint` and `FlutterError.presentError` placeholders.
- **`TalkerRiverpodObserver`** is passed to `ProviderScope.observers`, so every provider built / disposed / failed event lands in talker.
- **`TalkerDioLogger`** is wired inline as the first interceptor on `dioProvider`, so every request, response, and Dio error is logged structurally.

**`lib/core/logging/talker.dart`:**

```dart
import 'package:talker_flutter/talker_flutter.dart';

final talker = TalkerFlutter.init();
```

**Loggers are global, not provided.** Don't put `talker` behind a Riverpod provider. Logging is a universally-accessed side effect (like `print`), not a scoped dependency — repositories, utility functions, isolates, and bootstrap-level error handlers all need access without `ref`. Threading a logger through DI is friction with no real testability benefit (most teams don't mock loggers anyway). Same exception applies to other "process-wide constants" that aren't real DI targets.

**Tuning noise:** default settings log every event. Tune via `TalkerSettings`, `TalkerRiverpodLoggerSettings`, `TalkerDioLoggerSettings` once volume becomes a problem in real use. Particularly worth knowing: `TalkerRiverpodLoggerSettings(printProviderAdded: false, printProviderUpdated: false)` cuts the bulk of provider-lifecycle noise.

**In-app log viewer.** `lib/core/logging/log_viewer_screen.dart` is a `@RoutePage()`-annotated wrapper around `TalkerScreen(talker: talker)` — registered in `AppRouter` as `LogViewerRoute`. A `kDebugMode`-gated `Icons.bug_report` AppBar action on `ExampleListScreen` pushes it via `context.router.push(const LogViewerRoute())`. Gated to debug only because shipping the full structured-log dump in a production build is a leak risk; promote behind a more deliberate trigger (shake gesture, hidden gesture in About screen) if a release-build viewer is ever needed.

### Local database — Drift

Drift is opened via `drift_flutter`'s `driftDatabase()` helper, which handles platform-specific connection setup (NativeDatabase on mobile/desktop, WasmDatabase on web). The `AppDatabase` class is pure Drift; the Riverpod provider sits in a sibling file.

```dart
// lib/core/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'app_database'));

  @override
  int get schemaVersion => 1;
}
```

```dart
// lib/core/database/app_database_provider.dart
import 'package:{{project_name.snakeCase()}}/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
```

**Conventions:**

- **Tables are co-located with their feature** (`lib/features/<feature>/data/tables/<table>.dart`) and registered in `AppDatabase`'s `@DriftDatabase(tables: [...])` annotation. No central `tables/` folder under `core/`.
- **Default to using drift's row types end-to-end** — storage → repository return → presentation watchers. Don't introduce a separate DTO or ViewModel just to "isolate" the storage layer; for same-shape data that's pure ceremony. Reach for a freezed DTO or a ViewModel only when shapes actually diverge between layers: wire format ≠ storage (different field names, nested objects, fields drift doesn't persist), or presentation needs computed/derived fields the row class doesn't have. Wire-only DTOs (used solely in network parsing inside the repository, never returned upward) are fine and don't count as proliferation. (Side note: this template uses hand-written providers, which sidesteps the `riverpod_generator` 4.x bug around drift's `*Data` row types entirely — see "Riverpod providers" above.)
- **Schema versioning:** `schemaVersion` starts at `1` and increments per breaking schema change. `MigrationStrategy` is scaffolded with explicit `onCreate`, no-op `onUpgrade` (with a comment block describing how to switch to `stepByStep` once a v2 exists), and `beforeOpen` that enables SQLite foreign keys (`PRAGMA foreign_keys = ON`) — drift's #1 correctness tip since SQLite has them off by default.
- **Migrations workflow** (when v2 ships):
  1. `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/` — dumps the *current* schema to JSON.
  2. `dart run drift_dev schema steps drift_schemas/ lib/core/database/schema_versions.dart` — generates typed `Schema1`/`Schema2`/... helpers.
  3. Replace the no-op `onUpgrade` body with `stepByStep(from1To2: (m, schema) async { ... })(m, from, to)`.
  4. Optionally use drift's schema verifier in tests to catch migration bugs before release.
- **DAOs:** add `@DriftAccessor` per-feature DAOs (in the feature's `data/` folder) when a feature accumulates more than a handful of queries. Avoid central DAOs in `core/`.
- **Codegen:** changes to tables/database/DAO files require `dart run build_runner build --delete-conflicting-outputs` (or `watch`) to regenerate `.g.dart` files.

**Pending additions** (added when concretely needed):

- Web support: when targeting web, run `dart run drift_flutter:setup` (or whatever the current command is) to copy `sqlite3.wasm` and the worker into `web/`.
- Type converters in `lib/core/database/converters/` — add when first non-primitive column type appears (e.g. `DateTime` JSON, sealed enums).
- Migration helpers / schema dumps via `dart run drift_dev schema dump` once schema evolves.

### Routing — auto_route

`auto_route` provides typed routes via codegen. The router is owned by Riverpod, `MaterialApp.router` consumes it.

**`lib/core/router/app_router.dart`:**

```dart
import 'package:auto_route/auto_route.dart';
import 'package:{{project_name.snakeCase()}}/features/example/presentation/screens/example_list_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: ExampleListRoute.page, initial: true),
  ];
}
```

**`RouteType.adaptive()` as the default.** auto_route's built-in default is `RouteType.material()`, which gives every platform Material's slide-from-bottom transition — wrong on iOS/macOS and missing the iOS edge-swipe-back gesture entirely. `RouteType.adaptive()` resolves at runtime to Cupertino on iOS/macOS (slide-from-right + swipe-back) and Material on Android/desktop. Per-route override via `AutoRoute(..., type: RouteType.modal())` for screens that should be presented (sign-in, settings overlays) rather than navigated to.

**`lib/core/router/app_router_provider.dart`:**

```dart
final appRouterProvider = Provider<AppRouter>((ref) => AppRouter());
```

Pure Dart router class, hand-written keep-alive `Provider` — same shape as `dioProvider` and `appDatabaseProvider`. No Riverpod imports in `app_router.dart` (class-vs-wiring rule).

**Screens are annotated with `@RoutePage()`.** The annotation is what triggers `auto_route_generator` to emit the matching `*Route` class (e.g. `ExampleListRoute`) in `app_router.gr.dart`. Screen file imports `package:auto_route/auto_route.dart`. Run `dart run build_runner build --delete-conflicting-outputs` after adding/renaming an annotated screen.

**`app.dart` is a `ConsumerStatefulWidget` and caches the `RouterConfig`:**

```dart
class _AppState extends ConsumerState<App> {
  late final _routerConfig = ref.read(appRouterProvider).config();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      ...
      routerConfig: _routerConfig,
    );
  }
}
```

`RootStackRouter.config()` returns a fresh `RouterConfig` (new `RouterDelegate` + `RouteInformationParser`) on each call. Computing it inside `build` would hand `MaterialApp.router` a new delegate every rebuild and drop nav state. Cache it in `late final` on the `State` so it's computed once. `ref.read` (not `watch`) because `appRouterProvider` is keep-alive infrastructure — `watch` would falsely suggest the value can change.

**Why a Provider, not a top-level singleton.** Talker is global because logging is a universally-accessed side effect with no real DI value. The router is different: it's stateful (owns the nav stack), notifiers will reach for it for programmatic navigation (`ref.read(appRouterProvider).push(...)`), and route guards (when auth lands) will need to read other providers. Putting it behind a `Provider` matches the `dio`/`AppDatabase` shape and makes those future use cases natural.

**Pending additions** (added when concretely needed):

- Deep-link parsing rules and path-based URL strategy on web (`usePathUrlStrategy`) — added if/when web is a real target.
- Route observers beyond `TalkerRouteObserver` (e.g. analytics) wired via `RouterConfig.navigatorObservers` when the first additional observer concretely lands.

### Auth (Logto variant)

The brick will eventually offer multiple auth providers as parallel folders under `lib/core/auth/`. The first shipped variant is Logto via `logto_dart_sdk`; future variants (Firebase, custom JWT) will land as sibling folders. Each is fully self-contained — no shared abstract base class — because the providers' SDK shapes diverge enough (Logto's redirect flow vs Firebase's in-app credentials, access-token-per-resource vs single ID token) that any unified surface would over-fit one or under-fit the other. Brick swap = "include this folder, exclude the others."

**Layout:**

```
lib/core/auth/logto/
  auth_user.dart                 # freezed AuthUser (OIDC claims-derived)
  auth_repository.dart           # global authRepository, wraps LogtoClient
  auth_controller.dart           # AsyncNotifier<bool> + provider — durable session
  sign_in_controller.dart        # AsyncNotifier<void> + provider — operation state
  current_user_provider.dart     # FutureProvider<AuthUser?> — lazy claims fetch
  auth_change_listenable.dart    # ReevaluateListenable bridging Riverpod → auto_route
  auth_guard.dart                # AutoRouteGuard subclass
  auth_token_interceptor.dart    # Dio interceptor (attach + 401 handling)
  screens/
    sign_in_screen.dart          # @RoutePage() — Logto button + browser flow
```

**Architecture (scope: cold-start session resolution + return-to-route + 401 / token-revocation handling):**

- **`AuthRepository` is a top-level global** (`final authRepository = AuthRepository._()`), not behind a Riverpod provider. It's stateless, has no DI dependencies (constructs `LogtoClient` from `Env` constants), and is never overridden in tests. Same precedent as `talker`: stateless infrastructure with no real DI value lives at module top level rather than fronted by a Riverpod provider.
- **`AuthController extends AsyncNotifier<bool>`** — durable session state, keep-alive. `bool` because the cheap question (am I signed in?) is what guards and gates need; full user data lives in a separate provider.
- **`SignInController extends AsyncNotifier<void>`** — operation state for the sign-in screen. Auto-dispose. `retry: (_, _) => null` because sign-in is one-shot user-driven; default exponential backoff would silently re-attempt the browser flow on dismissal.
- **`currentUserProvider` is a `FutureProvider<AuthUser?>`** — fetches OIDC claims only when watched. Invalidated by `AuthController.signOut` and `evict` so user data doesn't go stale.
- **`AuthChangeListenable`** (subclass of auto_route's `ReevaluateListenable`) bridges `authControllerProvider` to the router. Filters to **confirmed `bool ↔ bool` transitions only** (skips loading edges, errors, the cold-start `null → bool` resolution) — that filter is what keeps the listenable from chattering during normal operation.
- **`AuthGuard.onNavigation`** awaits `authControllerProvider.future` (with `.catchError((_) => false)` for safety) on the initial nav, decides via `value == true`, and uses `resolver.redirectUntil(SignInRoute(onSuccess: ...))` for the unauthed branch. Cold-start gets a guard-driven decision; later state changes get listenable-driven re-evaluation. Two mechanisms that don't overlap.

**State-vs-routing decision split:**

| Mechanism | Drives |
|---|---|
| Guard's `await future` | Initial cold-start nav decision (does the user land on `ExampleListRoute` or `SignInRoute`?). |
| `AuthChangeListenable` → `reevaluateGuards()` | Sign-out, 401 eviction. Both flip `AuthState` from `true → false`; the listener fires guards on the existing stack and the user is redirected. |
| `SignInRoute(onSuccess: ...)` callback | Sign-in success. The screen calls `widget.onSuccess?.call(true)`; the resolver completes the original held navigation. No reliance on the listener for this path. |

**Why this isn't redundant.** Sign-in success (`false → true`) is handled by the explicit callback — `AuthChangeListenable`'s filter passes that transition through to `notifyListeners`, but it's a no-op because the guard would just see `value == true` and approve, which is what the resolver was already doing. Sign-out / eviction (`true → false`) requires the listener because there's no held resolver in those flows — the user is already on a protected route.

**Token interceptor behaviour.** `AuthTokenInterceptor` attaches the Logto access token on every request (calls `authRepository.backendToken()`). On 401:
1. Mark the request `_retriedKey: true` so retries can't loop.
2. Re-call `backendToken()` — Logto's SDK transparently refreshes via refresh token if available.
3. If refresh returned null AND `authRepository.isSignedIn()` confirms no session → call `authController.evict()` (which fires the listenable → guard redirects to sign-in). Otherwise propagate the 401 to the caller — distinguishes session expiry (evict) from transient backend issues (don't sign the user out).
4. If a fresh token was obtained, retry the original request via `dio.fetch(retryOptions)` and `handler.resolve` to the original caller.

**Sign-out is local-first.** `AuthController.signOut` wraps the SDK call in try/finally — if Logto's hosted sign-out endpoint fails (network, server error), the user is still evicted locally. Remote sign-out failure is logged via talker but doesn't block local cleanup.

**Sign-in screen UX detail.** The screen flips `isSigningIn = true` *before* opening the browser, not after. That way the "in transition" state covers the entire flow (browser open → close → resolver completion → route swap) without a flash of the sign-in button between browser-close and route-change. Reset to `false` only on error.

**Env constants:** `LOGTO_ENDPOINT`, `LOGTO_APP_ID`, `AUTH_REDIRECT_URI` (default `io.logto://callback`), `AUTH_POST_SIGN_OUT_URI` (default `io.logto://home`), `API_RESOURCE` (no default — must be provided per project, registered in Logto admin as the API resource).

**Platform config.** Android requires a `flutter_web_auth_2.CallbackActivity` intent-filter for the redirect scheme (with `android:launchMode="singleTask"` so the redirect lands in the existing app task rather than spawning a sibling), and `minSdk = 18`. iOS requires nothing — `ASWebAuthenticationSession` handles the redirect natively. Logto admin needs the redirect URIs allow-listed and an API resource registered to match `Env.apiResource`.

**Pending (auth-adjacent):**

- Firebase variant in `lib/core/auth/firebase/` — different `signIn` signature (in-app credentials), uses Firebase ID tokens for backend validation.
- Custom JWT variant — for own-backend setups where the consumer issues their own tokens against their own `/auth/sign-in` endpoint.
- `AsyncError` state surfacing — currently the guard treats AsyncError as "not signed in" (safer default). When real "device offline at launch" UX appears, an explicit error state with a retry button on the splash equivalent is the path forward.
- Concurrent-request refresh queueing inside `AuthTokenInterceptor` — only matters when 5+ simultaneous 401s become a measurable problem.
- Multi-resource access tokens — `backendToken` currently calls `getAccessToken()` with no resource filter. If multiple backends are real, change the signature to take a resource and adjust the interceptor accordingly.
- Multi-tenant orgs via `getOrganizationToken` — if a B2B use case appears.

### Presentation layer organisation

Within a feature's `presentation/` folder:

- **`screens/`** — full-page screens (route destinations, own a `Scaffold`). Files end in `_screen.dart`.
- **`widgets/`** *(added when needed)* — feature-specific reusable widgets composed within screens. Files named by purpose: `*_card.dart`, `*_tile.dart`, `*_dialog.dart`, `*_button.dart`. Don't pre-create the folder; it appears when the first reusable widget is extracted.
- **Files directly in `presentation/`** — providers and notifiers (e.g. `example_sync.dart`, `example_list.dart`). Keep flat unless 3+ accumulate, then optionally introduce `presentation/providers/`.

Cross-feature reusable widgets (used by **two or more** features) graduate to `lib/core/widgets/`. Don't pre-share — wait for a real second consumer.

### Class-vs-wiring separation

Domain classes (repositories, services, table definitions) stay **pure Dart** — no Riverpod imports in the class file. Riverpod imports live in a thin sibling provider file.

```
features/user/data/
  user_repository.dart            # plain class with constructor injection
  user_repository_provider.dart   # hand-written `Provider` wiring it up
```

This keeps the class layer importable from non-Riverpod contexts (tests, isolates, CLI tooling) and confines Riverpod to the wiring layer.

---

## Layout reference

The actual layout of `lib/core/`, reflecting what's been built:

```
lib/core/
  auth/
    logto/                      # see "Auth (Logto variant)" above
  database/
    app_database.dart           # Drift database (schema registry)
    app_database_provider.dart
  env/
    env.dart                    # typed compile-time env constants
  errors/
    api_exception.dart          # sealed ApiException + DioExceptionToApi extension
  logging/
    talker.dart                 # global talker = TalkerFlutter.init()
    log_viewer_screen.dart      # @RoutePage() wrapper around TalkerScreen
  network/
    dio_provider.dart           # Dio + interceptors registration
  router/
    app_router.dart             # auto_route config (RootStackRouter)
    app_router_provider.dart
  theme/
    app_theme.dart              # SeedColorScheme + page transitions
```

Each sub-folder is documented in its dedicated "Decided foundations" section. New sub-folders graduate here only when there's a real cross-feature consumer; per-feature concerns stay under `features/<name>/`.