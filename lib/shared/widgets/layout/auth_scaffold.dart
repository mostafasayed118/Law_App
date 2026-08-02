import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../legalhub_components.dart' show LegalHubAppBar;

/// The shared scrollable, width-constrained body shell used by the auth and
/// onboarding screens.
///
/// Renders a [LegalHubAppBar] with an optional [leading] back button, then a
/// vertically-centered, horizontally-padded, width-constrained scroll area for
/// [child]. This consolidates the repeated
/// `Scaffold > SafeArea > Center > SingleChildScrollView > ConstrainedBox`
/// scaffolding across sign-in, sign-up, and the forgot-password flow.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.leading,
    this.maxWidth = 480,
    this.scrollPadding,
    super.key,
  });

  final Widget child;
  final Widget? leading;
  final double maxWidth;
  final EdgeInsetsGeometry? scrollPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LegalHubAppBar(leading: leading),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                scrollPadding ??
                const EdgeInsetsDirectional.fromSTEB(
                  LegalHubTheme.marginMobile,
                  LegalHubTheme.spaceXl,
                  LegalHubTheme.marginMobile,
                  LegalHubTheme.spaceXl,
                ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
