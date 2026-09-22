part of 'platform_admin_screen.dart';

/// Loads the admin lists once after the first frame.
///
/// Lives BELOW the screen's BlocProvider so its context resolves the cubit
/// (the member roster's arrival pattern: load whenever the lists are not
/// already visible or in flight).
class _LoadOnMount extends StatefulWidget {
  const _LoadOnMount({required this.child});

  final Widget child;

  @override
  State<_LoadOnMount> createState() => _LoadOnMountState();
}

class _LoadOnMountState extends State<_LoadOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final PlatformAdminState state = context.read<PlatformAdminCubit>().state;
      if (state is! PlatformAdminLoaded && state is! PlatformAdminLoading) {
        context.read<PlatformAdminCubit>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
