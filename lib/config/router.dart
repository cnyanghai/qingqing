import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../screens/welcome_screen.dart';
import '../screens/join_class_screen.dart';
import '../screens/setup_profile_screen.dart';
import '../screens/student/student_shell.dart';
import '../screens/student/home_screen.dart';
import '../screens/student/checkin_flow_screen.dart';
import '../screens/student/calendar_screen.dart';
import '../screens/student/profile_screen.dart';
import '../screens/teacher/teacher_shell.dart';
import '../screens/teacher/register_screen.dart';
import '../screens/teacher/dashboard_screen.dart';
import '../screens/teacher/student_list_screen.dart';
import '../screens/teacher/student_detail_screen.dart';
import '../screens/teacher/class_code_screen.dart';

/// Global navigation key
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _studentShellKey = GlobalKey<NavigatorState>();
final _teacherShellKey = GlobalKey<NavigatorState>();

/// App router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // S1: Welcome — redirect authenticated users to their home
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final userId = ref.read(currentUserIdProvider);
          if (userId == null) return null; // not logged in, show welcome

          final profileAsync = ref.read(profileProvider);
          final profile = profileAsync.valueOrNull;
          if (profile == null) return null; // no profile yet, show welcome

          if (profile.role == 'teacher') return '/teacher/home';
          return '/home'; // student or default
        },
        builder: (context, state) => const WelcomeScreen(),
      ),

      // S2: Join class
      GoRoute(
        path: '/join',
        builder: (context, state) => const JoinClassScreen(),
      ),

      // S3: Setup profile
      GoRoute(
        path: '/setup-profile',
        builder: (context, state) {
          final classroomId = state.extra as String?;
          return SetupProfileScreen(classroomId: classroomId);
        },
      ),

      // S5: Check-in flow (full screen, no bottom nav)
      GoRoute(
        path: '/checkin',
        builder: (context, state) => const CheckinFlowScreen(),
      ),

      // Student shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return StudentShell(navigationShell: navigationShell);
        },
        branches: [
          // S4: Home tab
          StatefulShellBranch(
            navigatorKey: _studentShellKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // S6: Calendar tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          // S7: Profile tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Teacher routes
      // T1: Register
      GoRoute(
        path: '/teacher/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // T5: Class code (standalone)
      GoRoute(
        path: '/teacher/class-code',
        builder: (context, state) {
          final code = state.extra as String? ?? '000000';
          return ClassCodeScreen(classCode: code);
        },
      ),

      // T4: Student detail (standalone)
      GoRoute(
        path: '/teacher/students/:id',
        builder: (context, state) {
          final studentId = state.pathParameters['id'] ?? '';
          return StudentDetailScreen(studentId: studentId);
        },
      ),

      // Teacher shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return TeacherShell(navigationShell: navigationShell);
        },
        branches: [
          // T2: Dashboard tab
          StatefulShellBranch(
            navigatorKey: _teacherShellKey,
            routes: [
              GoRoute(
                path: '/teacher/home',
                builder: (context, state) =>
                    const DashboardScreen(),
              ),
            ],
          ),
          // T3: Student list tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/students',
                builder: (context, state) =>
                    const StudentListScreen(),
              ),
            ],
          ),
          // Analytics tab (placeholder)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/analytics',
                builder: (context, state) => const Scaffold(
                  body: Center(child: Text('分析功能即将推出')),
                ),
              ),
            ],
          ),
          // Settings tab (placeholder)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/settings',
                builder: (context, state) => const Scaffold(
                  body: Center(child: Text('设置功能即将推出')),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
