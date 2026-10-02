import 'package:go_router/go_router.dart';
import '../screens/keys/ssh_keys_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/servers/add_edit_server_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScaffold(),
    ),
    GoRoute(
      path: '/keys',
      builder: (context, state) => const SshKeysScreen(),
    ),
    GoRoute(
      path: '/servers/add',
      builder: (context, state) => const AddEditServerScreen(),
    ),
  ],
);
