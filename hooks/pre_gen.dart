import 'dart:io';

import 'package:mason/mason.dart';

// Android URI scheme grammar: https://developer.android.com/guide/topics/manifest/data-element
// Starts with a letter, followed by letters, digits, +, -, .
final _schemeRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*$');

void run(HookContext context) {
  final orgName = context.vars['org_name'] as String;
  final projectName = context.vars['project_name'] as String;
  final supplied = (context.vars['auth_redirect_scheme'] as String).trim();

  // `flutter create --org X --project-name Y` composes the applicationId as
  // X.Y, so answering the org prompt with a full bundle id doubles the last
  // segment. Warn rather than abort: an org legitimately ending in the
  // project's name is possible. Loud because the id is locked once the app
  // ships — changing it later means a new listing, not an update.
  if (orgName.toLowerCase().endsWith('.${projectName.toLowerCase()}')) {
    context.logger.warn(
      'org_name "$orgName" already ends in "$projectName", so bundle ids will '
      'be "$orgName.$projectName". Answer the organisation prompt with just '
      'the reverse-domain prefix (e.g. "dev.calcode") if that is not what you '
      'want, and re-run before publishing anywhere.',
    );
  }

  // Mason has no computed defaults, so a blank answer is the sentinel for
  // "derive it". Underscores are illegal in a URI scheme, so the snake_case
  // package name is param-cased: dev.calcode + recipe_scanner gives
  // dev.calcode.recipe-scanner.
  final scheme = supplied.isEmpty ? '${orgName.toLowerCase()}.${projectName.paramCase}' : supplied;

  // Validated here rather than in post_gen so a bad org_name or project_name
  // aborts before any files are written.
  if (!_schemeRegex.hasMatch(scheme)) {
    final origin = supplied.isEmpty ? ' derived from org_name "$orgName" and project_name "$projectName"' : '';
    context.logger.err(
      'Invalid auth_redirect_scheme: "$scheme"$origin. '
      'Must match Android URI-scheme grammar: starts with a letter, then letters/digits/+/-/.',
    );
    exit(1);
  }

  context.vars = {...context.vars, 'auth_redirect_scheme': scheme};
}
