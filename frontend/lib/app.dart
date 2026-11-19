// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:mine_wadhwani/core/constants/app_constants.dart';
// import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
// import 'package:mine_wadhwani/core/routing/app_router.dart';
// import 'package:mine_wadhwani/core/routing/auth_guard.dart';
// import 'package:mine_wadhwani/core/theme/app_theme.dart';
// import 'package:mine_wadhwani/data/datasources/auth/auth_local_datasource.dart';
// import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_bloc.dart';
// import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_event.dart';
// import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_state.dart';
// import 'package:mine_wadhwani/core/routing/app_router.gr.dart';

// class App extends StatefulWidget {
//   const App({super.key});

//   @override
//   State<App> createState() => _AppState();
// }

// class _AppState extends State<App> {
//   late final AppRouter _appRouter;

//   @override
//   void initState() {
//     super.initState();
//     _appRouter = AppRouter(
//       authGuard: AuthGuard(localDataSource: sl<AuthLocalDataSource>()),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (_) => sl<AuthBloc>()..add(const AuthCheckRequested()),
//       child: BlocListener<AuthBloc, AuthState>(
//         listener: (context, state) {
//           if (state is Unauthenticated) {
//             _appRouter.replaceAll([const LoginRoute()]);
//           }
//         },
//         child: MaterialApp.router(
//           title: AppConstants.appName,
//           theme: AppTheme.lightTheme,
//           debugShowCheckedModeBanner: false,
//           routerConfig: _appRouter.config(),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mine_wadhwani/core/constants/app_constants.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/routing/app_router.dart';
import 'package:mine_wadhwani/core/routing/auth_guard.dart';
import 'package:mine_wadhwani/core/theme/app_theme.dart';
import 'package:mine_wadhwani/data/datasources/auth/auth_local_datasource.dart';
import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_bloc.dart';
import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_event.dart';
import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_state.dart';
import 'package:mine_wadhwani/presentation/bloc/draft_bloc/draft_bloc.dart';
import 'package:mine_wadhwani/presentation/bloc/draft_bloc/draft_event.dart';
import 'package:mine_wadhwani/core/routing/app_router.gr.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AppRouter _appRouter;

  late final AuthBloc _authBloc = sl<AuthBloc>()..add(const AuthCheckRequested());

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(
      authGuard: AuthGuard(localDataSource: sl<AuthLocalDataSource>()),
    );
    ApiClient.sessionExpired.addListener(_onSessionExpired);
  }

  // Server said the saved login is no longer valid: clear it and go to the login screen.
  void _onSessionExpired() => _authBloc.add(const AuthLogoutRequested());

  @override
  void dispose() {
    ApiClient.sessionExpired.removeListener(_onSessionExpired);
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        // DraftBloc is provided at the root so it's accessible from
        // HomePage, StockpileOverviewPage, and PendingInspectionsScreen
        // without needing to pass it down manually.
        BlocProvider(
          create: (_) => sl<DraftBloc>()..add(const LoadDrafts()),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            _appRouter.replaceAll([const LoginRoute()]);
          }
        },
        child: ValueListenableBuilder<String>(
          valueListenable: AppLanguage.current,
          builder: (context, _, __) => MaterialApp.router(
            title: AppConstants.appName,
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            routerConfig: _appRouter.config(),
          ),
        ),
      ),
    );
  }
}