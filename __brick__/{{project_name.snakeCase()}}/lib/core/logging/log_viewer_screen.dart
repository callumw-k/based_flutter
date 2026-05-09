import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:{{project_name.snakeCase()}}/core/logging/talker.dart';
import 'package:talker_flutter/talker_flutter.dart';

@RoutePage()
class LogViewerScreen extends StatelessWidget {
  const LogViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TalkerScreen(talker: talker);
  }
}