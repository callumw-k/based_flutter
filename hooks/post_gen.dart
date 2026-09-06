import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  final projectName = context.vars['project_name'] as String;
  final orgName = context.vars['org_name'] as String;
  final appName = context.vars['app_name'] as String;
  // Already validated (and derived, if left blank) in pre_gen.dart.
  final scheme = context.vars['auth_redirect_scheme'] as String;
  final auth = context.vars['auth'] as bool;
  final logger = context.logger;

  // Mason invokes hooks with CWD set to where `mason make` ran, not the
  // generated subdirectory. Move into the project so all subsequent commands
  // and relative file paths (AndroidManifest.xml, build.gradle) resolve
  // against the correct tree.
  final projectDir = Directory(projectName);
  if (!projectDir.existsSync()) {
    logger.err('Project directory $projectName not found in ${Directory.current.path}; aborting.');
    exit(1);
  }
  Directory.current = projectDir;

  // 1. Pin the Flutter SDK before anything else runs. The brick ships
  // `.fvmrc`; `fvm install` reads it, downloads the pinned version if it's
  // absent and links `.fvm/`. Every Flutter invocation below is proxied
  // through fvm so generation can't silently run against whatever SDK
  // happens to be on PATH — a newer one produces code that doesn't analyse.
  await _requireFvm(logger);
  await _runCmd(logger, 'fvm', ['install'], progress: 'Pinning Flutter SDK');

  // 2. Scaffold platform directories.
  //
  // ponytail: `flutter create` runs its own resolution as
  // `dart pub --directory . get --example` (see `create --verbose`), not
  // `flutter pub get`. On 3.47.2 that moves the SDK-vendored packages off the
  // lock we ship: meta 1.19.0 to 1.18.3, vector_math, code_assets, hooks,
  // record_use, objective_c, native_toolchain_c, and it drops process. Step 5
  // then finds the rewritten lock satisfiable and leaves it, so the project
  // ends up off the tested dependency set. 3.41.9 leaves the lock alone, so
  // this arrived between those releases. Hold the lock aside and put it back.
  // Retest on the next SDK bump and delete this if it is no longer needed.
  final lockFile = File('pubspec.lock');
  final shippedLock = lockFile.existsSync() ? lockFile.readAsStringSync() : null;
  await _runCmd(
    logger,
    'fvm',
    ['flutter', 'create', '.', '--org', orgName, '--project-name', projectName],
    progress: 'Scaffolding platform directories',
  );
  if (shippedLock != null) lockFile.writeAsStringSync(shippedLock);

  // 3. Patch AndroidManifest.xml: display name + network permissions + Logto
  // intent-filter.
  _patchAndroidManifest(scheme, projectName, appName, auth, logger);

  // 4. Patch ios/Runner/Info.plist: display name.
  _patchIosDisplayName(appName, logger);

  // 5. Fetch dependencies.
  await _runCmd(logger, 'fvm', ['flutter', 'pub', 'get'], progress: 'Fetching dependencies');

  // Warn rather than abort: a platform this template has not been generated on
  // may legitimately need a different resolution, but silent drift from the
  // tested set is what makes a template rot.
  if (shippedLock != null && lockFile.readAsStringSync() != shippedLock) {
    logger.warn(
      'pubspec.lock changed during generation, so this project is not on the '
      'exact dependency set the template was tested against. Run '
      '"fvm flutter analyze" before relying on it.',
    );
  }

  // 6. Generate code. Use `pub run` (not `dart run`) so this dispatches
  // through the same Dart SDK that `flutter pub get` just resolved against;
  // a bare `dart` may resolve to a separate SDK install that doesn't see the
  // freshly-fetched packages.
  await _runCmd(
    logger,
    'fvm',
    ['flutter', 'pub', 'run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    progress: 'Generating code',
  );

  // 7. Initialise git and make initial commit.
  await _runCmd(logger, 'git', ['init'], progress: 'Initialising git');
  await _runCmd(logger, 'git', ['add', '.']);
  await _runCmd(
    logger,
    'git',
    ['commit', '-m', 'Initial commit from based_flutter brick'],
    progress: 'Creating initial commit',
  );
}

Future<void> _requireFvm(Logger logger) async {
  try {
    final result = await Process.run('fvm', ['--version'], runInShell: true);
    if (result.exitCode == 0) return;
  } on ProcessException {
    // Not on PATH at all; same remedy as a non-zero exit.
  }
  logger.err(
    'fvm was not found on PATH. This template pins its Flutter SDK in .fvmrc '
    'and runs every Flutter command through fvm, so generation cannot '
    'continue without it. Install fvm '
    '(https://fvm.app/documentation/getting-started/installation), then '
    're-run "mason make based_flutter".',
  );
  exit(1);
}

Future<void> _runCmd(
  Logger logger,
  String executable,
  List<String> args, {
  String? progress,
}) async {
  final p = progress != null ? logger.progress(progress) : null;
  final result = await Process.run(executable, args, runInShell: true);
  if (result.exitCode != 0) {
    p?.fail();
    logger.err('$executable ${args.join(' ')} failed (exit ${result.exitCode}):');
    if ((result.stderr as String).isNotEmpty) logger.err(result.stderr.toString());
    if ((result.stdout as String).isNotEmpty) logger.err(result.stdout.toString());
    exit(result.exitCode);
  }
  p?.complete();
}

void _patchAndroidManifest(
  String scheme,
  String projectName,
  String appName,
  bool auth,
  Logger logger,
) {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    logger.err('AndroidManifest.xml not found at ${manifest.path}; aborting.');
    exit(1);
  }

  var content = manifest.readAsStringSync();

  // `flutter create --project-name` sets android:label to the snake_case
  // package name; swap in the human-readable display name. Done before the
  // block insertions below so the CallbackActivity's own android:label can
  // never be caught by this replacement.
  content = content.replaceAll(
    'android:label="$projectName"',
    'android:label="${_escapeXml(appName)}"',
  );

  // Strip `android:taskAffinity=""` (emitted by `flutter create`'s template).
  // Auth-only: the empty value only matters because it breaks the redirect
  // handoff between MainActivity and the callback activity.
  // Empty taskAffinity disrupts the OAuth redirect handoff between MainActivity
  // and the flutter_web_auth_2 CallbackActivity. Match the whole line including
  // its leading newline + indentation.
  if (auth) {
    content = content.replaceAll(
      RegExp(r'\n\s*android:taskAffinity=""'),
      '',
    );
  }

  // Insert network permissions before <application>. Flutter's default main
  // manifest declares neither, so release builds silently fail to make HTTP
  // requests. INTERNET is required for Dio. ACCESS_NETWORK_STATE is included
  // pre-emptively for future connectivity-aware features (connectivity_plus
  // etc.) so a manifest edit isn't needed later. Idempotent.
  if (!content.contains('android.permission.INTERNET')) {
    const applicationTag = '<application';
    final appIdx = content.indexOf(applicationTag);
    if (appIdx == -1) {
      logger.err('Could not locate <application in AndroidManifest.xml; aborting.');
      exit(1);
    }
    const permissionsBlock = '''<uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    ''';
    content = content.substring(0, appIdx) + permissionsBlock + content.substring(appIdx);
  }

  // Insert the flutter_web_auth_2 CallbackActivity block before </application>.
  // MainActivity itself is left untouched — its Flutter-default launchMode
  // ("singleTop") is correct; the singleTask requirement applies to the
  // callback activity, not the main one. Idempotent.
  if (auth && !content.contains('com.linusu.flutter_web_auth_2.CallbackActivity')) {
    const closingTag = '</application>';
    final closingIdx = content.indexOf(closingTag);
    if (closingIdx == -1) {
      logger.err('Could not locate </application> in AndroidManifest.xml; aborting.');
      exit(1);
    }

    final activityBlock = '''
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true"
            android:launchMode="singleTask">
            <intent-filter android:label="flutter_web_auth_2">
                <action android:name="android.intent.action.VIEW" />

                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />

                <data android:scheme="$scheme" />
            </intent-filter>
        </activity>

    ''';

    content = content.substring(0, closingIdx) + activityBlock + content.substring(closingIdx);
  }

  manifest.writeAsStringSync(content);

  // Verify the patches landed; substring-style writes silently no-op if the
  // anchor strings change between Flutter versions.
  final after = manifest.readAsStringSync();
  final authPatchesLanded = !auth ||
      (after.contains('com.linusu.flutter_web_auth_2.CallbackActivity') &&
          after.contains('android:scheme="$scheme"'));
  if (!after.contains('android:label="${_escapeXml(appName)}"') ||
      !after.contains('android.permission.INTERNET') ||
      !after.contains('android.permission.ACCESS_NETWORK_STATE') ||
      !authPatchesLanded) {
    logger.err(
      'AndroidManifest patch did not apply as expected. '
      'Edit ${manifest.path} manually: set android:label="${_escapeXml(appName)}" on <application>, ensure <uses-permission android:name="android.permission.INTERNET" /> '
      'and <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" /> are declared before '
      '<application>, and a CallbackActivity block is inserted before </application> with '
      'android:name="com.linusu.flutter_web_auth_2.CallbackActivity" and <data android:scheme="$scheme" />.',
    );
    exit(1);
  }
}

// `flutter create` derives CFBundleDisplayName by title-casing the project
// name, so there's no predictable literal to match on. Anchor on the key
// instead and rewrite the <string> that follows it. CFBundleName is left
// alone: that's the short bundle name, which should stay the package name.
final _displayNameRegex = RegExp(
  r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
);

void _patchIosDisplayName(String appName, Logger logger) {
  final plist = File('ios/Runner/Info.plist');
  if (!plist.existsSync()) {
    logger.err('Info.plist not found at ${plist.path}; aborting.');
    exit(1);
  }

  final escaped = _escapeXml(appName);
  final content = plist.readAsStringSync().replaceFirstMapped(
        _displayNameRegex,
        (m) => '${m[1]}$escaped${m[2]}',
      );
  plist.writeAsStringSync(content);

  // Verify: replaceFirstMapped silently no-ops if the key is absent or the
  // plist layout changes between Flutter versions.
  final match = _displayNameRegex.firstMatch(plist.readAsStringSync());
  if (match == null || !match.group(0)!.contains('<string>$escaped</string>')) {
    logger.err(
      'Info.plist patch did not apply as expected. '
      'Edit ${plist.path} manually: set the <string> under '
      '<key>CFBundleDisplayName</key> to "$appName".',
    );
    exit(1);
  }
}

// Escape the five XML predefined entities so display names containing `&`,
// quotes or angle brackets don't produce a malformed manifest or plist.
String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
