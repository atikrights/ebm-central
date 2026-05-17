import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../layout/app_layout.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/join_screen.dart';
import '../../features/mail/presentation/mail_dashboard_screen.dart';
import '../../features/mail/presentation/mail_settings_screen.dart';
import '../../features/auth/presentation/sso_gate_screen.dart';
import '../../features/workplace/presentation/single_company_manage_screen.dart';
import '../../features/projects/presentation/single_project_manage_screen.dart';
import '../../features/teams/presentation/teams_screen.dart';
import '../../features/teams/presentation/teams_control_screen.dart';
import '../../features/governance/presentation/authority_matrix_screen.dart';
import '../../shared/widgets/window_title_bar.dart';
import 'dart:io' if (dart.library.html) 'package:frontend/core/utils/io_stub.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────
// RouterNotifier — bridges Riverpod auth state → GoRouter refresh
// ─────────────────────────────────────────────
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // Notify GoRouter every time auth state changes
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isLoggedIn = authState.isLoggedIn;
    
    // Safety Check: Accessing /join without a token is not allowed
    final isJoinRoute = state.matchedLocation.startsWith('/join/');
    final hasToken = state.pathParameters.containsKey('token') && state.pathParameters['token']!.isNotEmpty;
    final hasRole = state.pathParameters.containsKey('role') && state.pathParameters['role']!.isNotEmpty;

    if (isJoinRoute && (!hasToken || !hasRole)) {
      return '/login'; // Redirect to login if no token or role provided
    }

    // Always allow /join/:role/:token if it has both
    if (isJoinRoute && hasToken && hasRole) return null;

    // Allowed public routes
    final publicRoutes = ['/login', '/sso-gate'];
    final isPublic = publicRoutes.any((r) => state.matchedLocation.startsWith(r));

    // Not logged in and not public → go to login
    if (!isLoggedIn && !isPublic) return '/login';

    // Already logged in → don't show login page (except SSO gate which handles its own logic)
    if (isLoggedIn && state.matchedLocation == '/login') return '/';

    return null;
  }
}

final _routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

// ─────────────────────────────────────────────
// App Router Provider
// ─────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: notifier.redirect,

    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Column(
            children: [
              if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
                WindowTitleBar(isDark: isDark),
              Expanded(child: child),
            ],
          );
        },
        routes: [
          // Main app (protected)
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const AppLayout(initialIndex: 1),
          ),

          GoRoute(
            path: '/live',
            name: 'live',
            builder: (context, state) => const AppLayout(initialIndex: 0),
          ),

          GoRoute(
            path: '/projects',
            name: 'projects',
            builder: (context, state) => const AppLayout(initialIndex: 37),
          ),

          GoRoute(
            path: '/companies',
            name: 'companies',
            builder: (context, state) => const AppLayout(initialIndex: 36),
          ),

          GoRoute(
            path: '/tasks',
            name: 'tasks',
            builder: (context, state) => const AppLayout(initialIndex: 38),
          ),

          GoRoute(
            path: '/assets',
            name: 'assets',
            builder: (context, state) => const AppLayout(initialIndex: 39),
          ),

          GoRoute(
            path: '/team',
            name: 'team',
            builder: (context, state) => const AppLayout(initialIndex: 33),
          ),

          GoRoute(
            path: '/teams-manage',
            name: 'teams_manage',
            builder: (context, state) => const TeamsScreen(),
          ),

          GoRoute(
            path: '/teams-control',
            name: 'teams_control',
            builder: (context, state) => const TeamsControlScreen(),
          ),

          // Authority Matrix — Role & Permission Control
          GoRoute(
            path: '/user-role',
            name: 'user_role',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const AuthorityMatrixScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),

          GoRoute(
            path: '/team/new',
            name: 'team_new',
            builder: (context, state) => const AppLayout(initialIndex: 34),
          ),

          GoRoute(
            path: '/team/tracking',
            name: 'team_tracking',
            builder: (context, state) => const AppLayout(initialIndex: 35),
          ),

          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const AppLayout(initialIndex: 6),
          ),

          GoRoute(
            path: '/chat',
            name: 'chat',
            builder: (context, state) => const AppLayout(initialIndex: 5),
          ),

          // Workplace Mail (protected)
          GoRoute(
            path: '/mail',
            name: 'mail',
            builder: (context, state) => const MailDashboardScreen(),
          ),

          // Mail Settings (protected)
          GoRoute(
            path: '/mail/settings',
            name: 'mail_settings',
            builder: (context, state) => const MailSettingsScreen(),
          ),

          // Login (public)
          GoRoute(
            path: '/login',
            name: 'login',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),

          // Join via invitation role and token (public deep link)
          GoRoute(
            path: '/join/:role/:token',
            name: 'join',
            pageBuilder: (context, state) {
              final token = state.pathParameters['token'] ?? '';
              final role = state.pathParameters['role'] ?? '';
              return CustomTransitionPage(
                key: state.pageKey,
                child: JoinScreen(token: token, role: role),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              );
            },
          ),

          // SSO Gate (Public/Private depending on token presence)
          GoRoute(
            path: '/authorize',
            name: 'sso_gate',
            builder: (context, state) {
              final target = state.uri.queryParameters['target'];
              return SSOGateScreen(targetUrl: target);
            },
          ),

          // Single Company Management (protected)
          GoRoute(
            path: '/company/:id',
            name: 'company_manage',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return CustomTransitionPage(
                key: state.pageKey,
                child: SingleCompanyManageScreen(companyId: id),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              );
            },
          ),

          // Single Project Management (protected)
          GoRoute(
            path: '/project/:id',
            name: 'project_manage',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return CustomTransitionPage(
                key: state.pageKey,
                child: SingleProjectManageScreen(projectId: id),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              );
            },
          ),
        ],
      ),
    ],

    // 404 Error Page
    errorBuilder: (context, state) => _RouterErrorPage(error: state.error),
  );
});

// ─────────────────────────────────────────────
// 404 Error Page
// ─────────────────────────────────────────────
class _RouterErrorPage extends StatelessWidget {
  final Exception? error;
  const _RouterErrorPage({this.error});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off_rounded, size: 64,
                color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 20),
            Text(
              'Page Not Found',
              style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Go Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
