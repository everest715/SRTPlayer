import 'package:go_router/go_router.dart';
import '../../features/files/presentation/home_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/dictation/presentation/dictation_screen.dart';
import '../../features/batch/presentation/batch_import_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/player/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PlayerScreen(audioFileId: id);
      },
    ),
    GoRoute(
      path: '/player/:id/dictation',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return DictationScreen(audioFileId: id);
      },
    ),
    GoRoute(
      path: '/batch-import',
      builder: (context, state) => const BatchImportScreen(),
    ),
  ],
);
