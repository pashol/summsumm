import 'package:flutter/material.dart';

class SpringPageRoute<T> extends PageRouteBuilder<T> {
  SpringPageRoute({required WidgetBuilder builder})
      : super(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final positionTween = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: const Cubic(0.34, 1.56, 0.64, 1)));

            final fadeTween = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOut));

            return SlideTransition(
              position: animation.drive(positionTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        );
}