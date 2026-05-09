// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [ExampleListScreen]
class ExampleListRoute extends PageRouteInfo<void> {
  const ExampleListRoute({List<PageRouteInfo>? children})
    : super(ExampleListRoute.name, initialChildren: children);

  static const String name = 'ExampleListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ExampleListScreen();
    },
  );
}

/// generated route for
/// [LogViewerScreen]
class LogViewerRoute extends PageRouteInfo<void> {
  const LogViewerRoute({List<PageRouteInfo>? children})
    : super(LogViewerRoute.name, initialChildren: children);

  static const String name = 'LogViewerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LogViewerScreen();
    },
  );
}

/// generated route for
/// [SignInScreen]
class SignInRoute extends PageRouteInfo<SignInRouteArgs> {
  SignInRoute({
    Key? key,
    void Function(bool)? onSuccess,
    List<PageRouteInfo>? children,
  }) : super(
         SignInRoute.name,
         args: SignInRouteArgs(key: key, onSuccess: onSuccess),
         initialChildren: children,
       );

  static const String name = 'SignInRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SignInRouteArgs>(
        orElse: () => const SignInRouteArgs(),
      );
      return SignInScreen(key: args.key, onSuccess: args.onSuccess);
    },
  );
}

class SignInRouteArgs {
  const SignInRouteArgs({this.key, this.onSuccess});

  final Key? key;

  final void Function(bool)? onSuccess;

  @override
  String toString() {
    return 'SignInRouteArgs{key: $key, onSuccess: $onSuccess}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SignInRouteArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}
