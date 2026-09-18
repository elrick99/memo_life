import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:go_router/go_router.dart';

import 'core/di/service_locator.dart';
import 'core/navigation/go_router_refresh_stream.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/profile_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/budget/bloc/accounts_bloc.dart';
import 'features/budget/bloc/categories_bloc.dart';
import 'features/budget/bloc/saving_goals_bloc.dart';
import 'features/budget/bloc/transactions_bloc.dart';
import 'features/budget/presentation/budget_dashboard_page.dart';
import 'features/notes/bloc/notes_bloc.dart';
import 'features/notes/presentation/note_public_view_page.dart';
import 'features/notes/presentation/notes_list_page.dart';
import 'features/reminders/bloc/reminders_bloc.dart';
import 'features/reminders/presentation/reminders_list_page.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/shell/presentation/splash_page.dart';

class MemoLifeApp extends StatelessWidget {
  const MemoLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Every feature Bloc is provided once here, above the router. This is
    // deliberate, not just convenience: `go_router`'s `StatefulShellRoute`
    // gives each tab its own nested Navigator, and `Navigator.push` inserts
    // the new route as a *sibling* of the current one in the Overlay — not
    // a descendant of it. A BlocProvider scoped to a single route's builder
    // is therefore invisible to any page later pushed on top of it. Putting
    // every Bloc above the whole router sidesteps that class of bug
    // entirely, for any push from anywhere.
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider<NotesBloc>.value(value: getIt<NotesBloc>()),
        BlocProvider<RemindersBloc>.value(value: getIt<RemindersBloc>()),
        BlocProvider<AccountsBloc>.value(value: getIt<AccountsBloc>()),
        BlocProvider<CategoriesBloc>.value(value: getIt<CategoriesBloc>()),
        BlocProvider<SavingGoalsBloc>.value(value: getIt<SavingGoalsBloc>()),
        BlocProvider<TransactionsBloc>.value(value: getIt<TransactionsBloc>()),
      ],
      child: Builder(
        builder: (context) {
          final router = _buildRouter(context.read<AuthBloc>());

          return MaterialApp.router(
            title: 'MemoLife',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            // Required by the note editor's rich-text toolbar
            // (QuillSimpleToolbar) for its tooltip/action strings.
            localizationsDelegates: const [
              FlutterQuillLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('fr'), Locale('en')],
            routerConfig: router,
          );
        },
      ),
    );
  }

  GoRouter _buildRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final status = authBloc.state.status;
        final location = state.matchedLocation;
        final isSplash = location == '/splash';
        final isAuthRoute = location == '/login' || location == '/register';

        // The note share deep link (Universal Links/App Links or the
        // `memolife://` scheme) must open for anyone, logged in or not —
        // the endpoint behind it is unauthenticated, so this bypasses the
        // login gate entirely rather than bouncing through `/login` first.
        if (location.startsWith('/notes/shared/')) {
          return null;
        }
        if (status == AuthStatus.unknown) {
          return isSplash ? null : '/splash';
        }
        if (status != AuthStatus.authenticated) {
          return isAuthRoute ? null : '/login';
        }
        // A guest is "authenticated enough" to enter the shell, but must
        // still be able to reach `/register` — the Profile screen's
        // "Créer un compte" CTA pushes it precisely so they can link an
        // account without losing their local data.
        if (isAuthRoute) {
          return authBloc.state.isGuest ? null : '/notes';
        }
        if (isSplash) {
          return '/notes';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/notes/shared/:token',
          builder: (context, state) =>
              NotePublicViewPage(token: state.pathParameters['token']!),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/notes',
                  builder: (context, state) => const NotesListPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/reminders',
                  builder: (context, state) => const RemindersListPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/budget',
                  builder: (context, state) => const BudgetDashboardPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfilePage(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
