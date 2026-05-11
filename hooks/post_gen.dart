import 'dart:io';

import 'package:mason/mason.dart';

// Android URI scheme grammar: https://developer.android.com/guide/topics/manifest/data-element
// Starts with a letter, followed by letters, digits, +, -, .
final _schemeRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*$');

Future<void> run(HookContext context) async {
  final projectName = context.vars['project_name'] as String;
  final orgName = context.vars['org_name'] as String;
  final scheme = context.vars['auth_redirect_scheme'] as String;
  final logger = context.logger;

  if (!_schemeRegex.hasMatch(scheme)) {
    logger.err(
      'Invalid auth_redirect_scheme: "$scheme". '
      'Must match Android URI-scheme grammar: starts with a letter, then letters/digits/+/-/.',
    );
    exit(1);
  }

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

  // 1. Scaffold platform directories.
  await _runCmd(
    logger,
    'flutter',
    ['create', '.', '--org', orgName, '--project-name', projectName],
    progress: 'Scaffolding platform directories',
  );

  // 2. Patch AndroidManifest.xml: network permissions + Logto intent-filter.
  _patchAndroidManifest(scheme, logger);

  // 3. Fetch dependencies.
  await _runCmd(logger, 'flutter', ['pub', 'get'], progress: 'Fetching dependencies');

  // 4. Generate code. Use `flutter pub run` (not `dart run`) so this dispatches
  // through the same Dart SDK that `flutter pub get` just resolved against;
  // a bare `dart` may resolve to a separate SDK install (FVM, system Dart)
  // that doesn't see the freshly-fetched packages.
  await _runCmd(
    logger,
    'flutter',
    ['pub', 'run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    progress: 'Generating code',
  );

  // 5. Initialise git and make initial commit.
  await _runCmd(logger, 'git', ['init'], progress: 'Initialising git');
  await _runCmd(logger, 'git', ['add', '.']);
  await _runCmd(
    logger,
    'git',
    ['commit', '-m', 'Initial commit from based_flutter brick'],
    progress: 'Creating initial commit',
  );
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

void _patchAndroidManifest(String scheme, Logger logger) {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    logger.err('AndroidManifest.xml not found at ${manifest.path}; aborting.');
    exit(1);
  }

  var content = manifest.readAsStringSync();

  // Strip `android:taskAffinity=""` (emitted by `flutter create`'s template).
  // Empty taskAffinity disrupts the OAuth redirect handoff between MainActivity
  // and the flutter_web_auth_2 CallbackActivity. Match the whole line including
  // its leading newline + indentation.
  content = content.replaceAll(
    RegExp(r'\n\s*android:taskAffinity=""'),
    '',
  );

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
  if (!content.contains('com.linusu.flutter_web_auth_2.CallbackActivity')) {
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
  if (!after.contains('android.permission.INTERNET') ||
      !after.contains('android.permission.ACCESS_NETWORK_STATE') ||
      !after.contains('com.linusu.flutter_web_auth_2.CallbackActivity') ||
      !after.contains('android:scheme="$scheme"')) {
    logger.err(
      'AndroidManifest patch did not apply as expected. '
      'Edit ${manifest.path} manually: ensure <uses-permission android:name="android.permission.INTERNET" /> '
      'and <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" /> are declared before '
      '<application>, and a CallbackActivity block is inserted before </application> with '
      'android:name="com.linusu.flutter_web_auth_2.CallbackActivity" and <data android:scheme="$scheme" />.',
    );
    exit(1);
  }
}
