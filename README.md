# based_flutter

A Mason brick that scaffolds an opinionated Flutter project: Riverpod 3 (hand-written providers), Drift, Dio, Logto auth, Talker logging, auto_route, freezed.

Generated projects pin their Flutter SDK and their entire dependency set to the versions the reference app was tested against, so a fresh `mason make` gives you a project that analyses and tests clean rather than whatever resolved latest today.

Two audiences, two READMEs. This one covers using the brick and maintaining it. The guide that ships inside generated projects lives at `__brick__/{{project_name.snakeCase()}}/README.md`.

## Requirements

| Tool | Why |
|---|---|
| [`mason_cli`](https://pub.dev/packages/mason_cli) | Runs the brick. `dart pub global activate mason_cli`. |
| [`fvm`](https://fvm.app) | The post-gen hook pins the Flutter SDK through fvm and aborts if it is missing. |
| `git` | The hook makes an initial commit in the generated project. |

You do not need a matching Flutter SDK on your PATH. `fvm install` reads the `.fvmrc` the brick ships and downloads the pinned version if you do not already have it.

## Install

From git:

```bash
mason add -g based_flutter --git-url https://github.com/callumw-k/based_flutter
```

That tracks `master`. Mason resolves it to a commit when you run `mason add`, then caches it, so `mason make` keeps using that commit until you re-run `mason add` to pick up later changes. Every commit on `master` ships a pinned Flutter SDK and a locked dependency set, so tracking the branch still gets you a tested combination rather than a moving target.

Add `--git-ref <tag>` when you want a specific one, to reproduce an older project or to hold a team on one version. Avoid `v0.1.0` and `v0.2.0`, which predate the SDK and lockfile pinning and generate projects that fail `flutter analyze`.

Per-project instead of globally, add a `mason.yaml` and run `mason get`:

```yaml
bricks:
  based_flutter:
    git:
      url: https://github.com/callumw-k/based_flutter
      # ref: v0.3.1   # optional, omit to track master
```

From a local checkout, for working on the brick itself:

```bash
mason add -g based_flutter --path /path/to/based_flutter
```

A local install resolves the path once and caches it. Move or rename the checkout and every `mason make` fails with `Could not find brick at <old path>` until you re-run `mason add -g` against the new location.

## Generate a project

Interactive, prompting for each variable:

```bash
mason make based_flutter
```

Non-interactive, which is what you want in a script:

```bash
mason make based_flutter -c vars.json -o ~/projects
```

```json
{
  "project_name": "acme_app",
  "app_name": "Acme",
  "description": "Acme's mobile app.",
  "org_name": "dev.calcode",
  "auth_redirect_scheme": ""
}
```

Output lands in `<output-dir>/<project_name>/`, defaulting to the current directory. Other flags worth knowing: `--on-conflict overwrite|skip|append` decides what happens when a file already exists, and `--no-hooks` skips post-gen entirely if you want the raw template.

## Brick variables

| Variable | Default | Purpose |
|---|---|---|
| `project_name` | `my_app` | Snake-case Dart package name, `lib/` directory, and import paths. |
| `app_name` | `My App` | MaterialApp title, Android `android:label`, iOS `CFBundleDisplayName`. |
| `description` | `A new Flutter project.` | pubspec description. |
| `org_name` | `dev.calcode` | Reverse-domain prefix, composed with `project_name` for bundle ids. |
| `auth_redirect_scheme` | derived | Logto OAuth redirect scheme (Env defaults + AndroidManifest intent-filter). |

`org_name` and `project_name` compose into the Android namespace and `applicationId` and the iOS bundle id, so `dev.calcode` plus `acme_app` gives `dev.calcode.acme_app`.

`auth_redirect_scheme` defaults to `org_name` plus the param-cased `project_name`, so `dev.calcode` and `recipe_scanner` derive `dev.calcode.recipe-scanner`. Underscores are illegal in a URI scheme, hence the param-casing. Answer the prompt (or set the key in a `-c` config) to override it. Leave the key out of that config entirely and mason falls back to prompting, which breaks a non-interactive run, so pass `""` for the derived value.

The scheme, derived or supplied, is validated against the Android URI scheme grammar before anything is written. It must start with a letter and contain only letters, digits, `+`, `-` and `.`. Whatever you end up with has to match the redirect URIs registered in your Logto admin console.

`app_name` and `description` are free text. Ampersands and quotes in them are escaped correctly for the manifest, the plist and Dart source.

## What the hooks do

`hooks/pre_gen.dart` runs first. It derives `auth_redirect_scheme` when the answer was blank and validates the result, so an org or project name that cannot form a URI scheme aborts before a single file is written.

`hooks/post_gen.dart` then runs seven steps against the generated directory, and aborts on the first failure rather than leaving a half-built project running:

1. `fvm install`, which reads the `.fvmrc` the brick ships and links `.fvm/`.
2. `fvm flutter create .` to scaffold the platform directories, using `--org` and `--project-name`. The shipped `pubspec.lock` is held aside across this step and restored afterwards. `flutter create` runs its own `dart pub get`, which on 3.47.2 re-resolves the SDK-vendored packages (`meta`, `vector_math`, `code_assets` and friends) off the locked versions. Flutter 3.41.9 leaves the lock alone, so this is worth retesting on each SDK bump.
3. Patch `AndroidManifest.xml`: set `android:label`, strip the empty `android:taskAffinity` that breaks the OAuth handoff, add the INTERNET and ACCESS_NETWORK_STATE permissions, and insert the `flutter_web_auth_2` callback activity carrying your redirect scheme.
4. Patch `ios/Runner/Info.plist` to set `CFBundleDisplayName`. `CFBundleName` keeps the package name.
5. `fvm flutter pub get`.
6. `fvm flutter pub run build_runner build --delete-conflicting-outputs`.
7. `git init`, `git add .`, and an initial commit.

Every Flutter invocation goes through fvm. A bare `flutter` would use whatever SDK sits on your PATH, and a newer one generates code that will not analyse.

Steps 3 and 4 verify their own edits and fail loudly with manual instructions if the anchors they match on have moved in a newer Flutter template.

## After generating

The generated project has a `README.md` covering the rest: copying `env/example.json` to `env/dev.json` and filling in the API and Logto credentials, registering the redirect URIs in Logto, and running with `--dart-define-from-file`. The architecture is documented in the project's `docs/template-foundations.md`.

Re-running `mason make` over an existing project is not safe. `flutter create .` is mostly additive but it will overwrite manually edited platform files. The generated README has a recovery section listing each post-gen step to run by hand if the hook aborts partway.

---

# Maintaining the brick

## Source of truth

Foundations are developed in the sibling repo `flutter_reference/` (a working Flutter app that exercises every brick foundation). After meaningful changes there, manually sync into this brick.

Layout assumption: `flutter_reference/` and `based_flutter/` live as siblings under the same parent (e.g. `~/Documents/projects/active/`). Override with `--source` if your layout differs.

Develop and test in `flutter_reference/`, never in `__brick__/`. The brick has no runnable app, so a change made only there is a change nobody has run.

## Sync workflow

```bash
# Default: auto-detect ../flutter_reference
dart run tool/sync.dart

# Explicit source path
dart run tool/sync.dart --source ../path/to/flutter_reference

# Dry run (no writes)
dart run tool/sync.dart --dry-run
```

The script:

1. Verifies the source's `pubspec.yaml` declares `name: flutter_reference`.
2. Wipes `__brick__/{{project_name.snakeCase()}}/lib/` and `__brick__/{{project_name.snakeCase()}}/docs/template-foundations.md` so deletions in source propagate.
3. Copies allowed files from source into the brick, applying token substitutions (see `tool/sync.dart` for the rule list).
4. Prints a summary plus `git status --short`.

The script never auto-commits. Review the diff in this repo, then commit manually.

Free-text variables use the triple-mustache form (`{{{app_name}}}`) in templates and in the sync substitution rules. Mason HTML-escapes `{{var}}`, so an ampersand in a display name would otherwise reach generated Dart source as `&amp;`. Identifier-shaped variables like `project_name` do not need it.

## Upgrading Flutter and dependencies

Both live in `flutter_reference/` and propagate through sync. Do them in one pass so you test one combination:

```bash
cd ../flutter_reference
fvm install 3.4x.y && fvm use 3.4x.y      # rewrites .fvmrc
fvm flutter pub upgrade --major-versions  # rewrites pubspec.yaml and pubspec.lock
fvm flutter analyze && fvm flutter test
# fix breakages here, where you can run the app
git commit -am "Bump Flutter to 3.4x.y"

cd ../based_flutter
dart run tool/sync.dart   # carries .fvmrc, pubspec.yaml and pubspec.lock across
git commit -am "Sync Flutter 3.4x.y"
```

`fvm flutter pub outdated` in the reference tells you when it is worth doing. The SDK pin and the lockfile guard different things, and a package bump alone is enough to break the template: dio 5.9.2 to 5.11.1 added an enum value that broke an exhaustive switch in `api_exception.dart`.

Bump `version:` in `brick.yaml`, tag the commit, and push the tag. Consumers pin by git ref, so an untagged change reaches nobody.

## Verifying a change

The brick has no test suite. Generating a project is the test:

```bash
mkdir /tmp/brick-check && cd /tmp/brick-check
cat > mason.yaml <<'YAML'
bricks:
  based_flutter:
    path: /path/to/based_flutter
YAML
mason get && mason make based_flutter -c vars.json --on-conflict overwrite
cd <project_name> && fvm flutter analyze && fvm flutter test
```

Both should come back clean. Use an `app_name` containing an ampersand to exercise the XML escaping.

To confirm sync is idempotent, copy the brick to a scratch directory, run `tool/sync.dart` there, and diff it against the working tree. Any difference means something in `__brick__/` is hand-edited but not in the exclusion list, and the next sync will silently revert it.

## Hand-authored brick files

`pubspec.lock` **is** synced: generated projects should start on the dependency set the reference was tested against, not on whatever resolves latest at generation time. The brick's own `.gitignore` ignores `pubspec.lock` for `tool/` and `hooks/`, with a `!__brick__/**/pubspec.lock` negation so the template's copy is still tracked.

These are **not** touched by sync (edit them in this repo):

- `__brick__/{{project_name.snakeCase()}}/README.md` — consumer-facing post-gen guide.
- `__brick__/{{project_name.snakeCase()}}/env/example.json` — placeholder env values.

## Excluded from sync

The sync script never copies these from `flutter_reference/`:

- `.dart_tool/`, `build/`
- `**/*.g.dart`, `**/*.freezed.dart` (regenerated by build_runner)
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` (generated by `flutter create .` in post_gen)
- `env/` (real auth values risk)
- `docs/pending.md`, `docs/template-purpose.md`, `docs/superpowers/`
- `.git/`, `.idea/`, `.vscode/`, `.claude/`
- `CLAUDE.md`, `devtools_options.yaml`

Platform directories are excluded because `flutter create .` regenerates them. Anything the reference hand-edits under `android/` or `ios/` has to be reproduced as a patch in `hooks/post_gen.dart`, or it will not reach generated projects.

## Troubleshooting

**`fvm was not found on PATH`**: install fvm. The brick pins its SDK through `.fvmrc` and will not generate without it.

**`Could not find brick at <path>`**: a global `mason add -g --path` install caching a directory that has since moved. Re-run `mason add -g based_flutter --path <new path>`.

**`Invalid auth_redirect_scheme`**: the value must start with a letter and contain only letters, digits, `+`, `-` and `.`. If you left the prompt blank, the error names the `org_name` and `project_name` it was derived from.

**`AndroidManifest patch did not apply as expected`** or the same for `Info.plist`: a newer Flutter template moved the anchor strings the hook matches on. The error names the exact edit to make by hand, then fix `hooks/post_gen.dart`.

**Generated project fails `flutter analyze` but the reference passes**: the two have drifted. Check that `pubspec.lock` and `.fvmrc` synced across, and compare `fvm flutter --version` in both.
