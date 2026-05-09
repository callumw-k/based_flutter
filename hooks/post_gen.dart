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

  // 1. Scaffold platform directories.
  await _runCmd(
    logger,
    'flutter',
    ['create', '.', '--org', orgName, '--project-name', projectName],
    progress: 'Scaffolding platform directories',
  );

  // 2. Patch AndroidManifest.xml: launchMode + Logto intent-filter.
  _patchAndroidManifest(scheme, logger);

  // 3. Fetch dependencies.
  await _runCmd(logger, 'flutter', ['pub', 'get'], progress: 'Fetching dependencies');

  // 4. Generate code.
  await _runCmd(
    logger,
    'dart',
    ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
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

  // Add android:launchMode="singleTask" to MainActivity if not already present.
  // Indentation here matches `flutter create`'s emitted activity block (12 spaces).
  if (!content.contains('android:launchMode="singleTask"')) {
    content = content.replaceFirst(
      'android:name=".MainActivity"',
      'android:name=".MainActivity"\n            android:launchMode="singleTask"',
    );
  }

  // Insert intent-filter inside the MainActivity block before its closing tag.
  // Anchor: the existing main intent-filter for android.intent.action.MAIN.
  // Insert the new intent-filter immediately after that block.
  const mainIntentClose = '</intent-filter>';
  final mainIdx = content.indexOf('android.intent.action.MAIN');
  if (mainIdx == -1) {
    logger.err('Could not locate android.intent.action.MAIN block in AndroidManifest.xml; aborting.');
    exit(1);
  }
  final closeIdx = content.indexOf(mainIntentClose, mainIdx);
  if (closeIdx == -1) {
    logger.err('Could not locate closing </intent-filter> after MAIN action; aborting.');
    exit(1);
  }

  final insertAt = closeIdx + mainIntentClose.length;
  final intentFilter = '''

            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="$scheme" />
            </intent-filter>''';

  // Avoid double-insertion if hook is re-run.
  if (!content.contains('android:scheme="$scheme"')) {
    content = content.substring(0, insertAt) + intentFilter + content.substring(insertAt);
  }

  manifest.writeAsStringSync(content);

  // Verify the patch landed; replaceFirst silently no-ops if the anchor strings change between Flutter versions.
  final after = manifest.readAsStringSync();
  if (!after.contains('android:scheme="$scheme"') ||
      !after.contains('android:launchMode="singleTask"')) {
    logger.err(
      'AndroidManifest patch did not apply as expected. '
      'Edit ${manifest.path} manually: add android:launchMode="singleTask" to MainActivity, '
      'and add an <intent-filter> with <data android:scheme="$scheme" /> inside MainActivity.',
    );
    exit(1);
  }
}
