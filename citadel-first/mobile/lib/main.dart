import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/auth/auth_bloc.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const CitadelFirstApp());
}

class CitadelFirstApp extends StatelessWidget {
  const CitadelFirstApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(),
      child: MaterialApp.router(
        title: 'New Citadel First',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF29ABE2)),
          useMaterial3: true,
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
