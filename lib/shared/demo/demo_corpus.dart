/// Shared synthetic demo corpus.
///
/// The fake gateways serve one non-PII demo organization, identity, and five
/// matter rows. Those values cross feature seams (auth session, membership
/// hydration, org roster, and every matter-referencing fake), so they live
/// here once instead of being re-declared per fake.
///
/// Feature-specific records (document ids, thread ids, invoice numbers,
/// statuses, dates, …) stay local to their fake; this corpus owns only the
/// identity and matter values the fakes share.
abstract final class DemoCorpus {
  static const String organizationId = 'org-demo';
  static const String organizationName = 'Demo Firm';
  static const String ownerId = 'demo-user';
  static const String ownerName = 'Demo user';
  static const String ownerEmail = 'demo@firm.com';
  static const String attorneyId = 'demo-attorney';

  static const List<String> matterIds = <String>[
    'matter-1',
    'matter-2',
    'matter-3',
    'matter-4',
    'matter-5',
  ];

  static const String matterTitleAcquisition = 'Demo acquisition review';
  static const String matterTitleLease = 'Commercial lease consultation';
  static const String matterTitleProcedural = 'Procedural review matter';
  static const String matterTitleFamily = 'Family status consultation';
  static const String matterTitleStartup = 'Startup formation advisory';

  static const List<String> matterTitles = <String>[
    matterTitleAcquisition,
    matterTitleLease,
    matterTitleProcedural,
    matterTitleFamily,
    matterTitleStartup,
  ];

  static const Map<String, String> matterTitlesById = <String, String>{
    'matter-1': matterTitleAcquisition,
    'matter-2': matterTitleLease,
    'matter-3': matterTitleProcedural,
    'matter-4': matterTitleFamily,
    'matter-5': matterTitleStartup,
  };
}
