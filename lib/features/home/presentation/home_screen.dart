import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/view_state_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.foundationReady,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                    Text(l10n.homeBody),
                  ],
                ),
              ),
            ),
            const SizedBox(height: LegalHubTheme.spaceXl),
            Expanded(
              child: Center(
                child: ViewStateView<String>(
                  state: const ViewSuccess<String>('foundation'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
