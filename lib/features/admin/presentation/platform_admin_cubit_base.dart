part of 'platform_admin_cubit.dart';

/// The cubit's shared seam field + initial state, split out so the audit
/// method group can live in a library-private mixin reading the same
/// instances.
class _PlatformAdminCubitBase extends Cubit<PlatformAdminState> {
  _PlatformAdminCubitBase(this._gateway) : super(const PlatformAdminInitial());

  final PlatformAdminGateway _gateway;
}
