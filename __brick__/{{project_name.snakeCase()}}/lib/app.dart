import 'package:flutter/material.dart';
import 'package:{{project_name.snakeCase()}}/core/auth/logto/auth_change_listenable.dart';
import 'package:{{project_name.snakeCase()}}/core/router/app_router_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'core/logging/talker.dart';
import 'core/theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final _routerConfig = ref.read(appRouterProvider).config(
    navigatorObservers: () => [TalkerRouteObserver(talker)],
    reevaluateListenable: ref.read(authChangeListenableProvider),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: '{{app_name}}',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _routerConfig,
    );
  }
}
