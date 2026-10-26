import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/shared/demo/demo_corpus.dart';

void main() {
  test('exposes the shared demo identity', () {
    expect(DemoCorpus.organizationId, 'org-demo');
    expect(DemoCorpus.organizationName, 'Demo Firm');
    expect(DemoCorpus.ownerId, 'demo-user');
    expect(DemoCorpus.ownerName, 'Demo user');
    expect(DemoCorpus.ownerEmail, 'demo@firm.com');
    expect(DemoCorpus.attorneyId, 'demo-attorney');
  });

  test('pins the five matter ids in order', () {
    expect(DemoCorpus.matterIds, <String>[
      'matter-1',
      'matter-2',
      'matter-3',
      'matter-4',
      'matter-5',
    ]);
  });

  test('pins the five matter titles in id order', () {
    expect(DemoCorpus.matterTitles, <String>[
      'Demo acquisition review',
      'Commercial lease consultation',
      'Procedural review matter',
      'Family status consultation',
      'Startup formation advisory',
    ]);
    expect(DemoCorpus.matterTitleAcquisition, DemoCorpus.matterTitles[0]);
    expect(DemoCorpus.matterTitleLease, DemoCorpus.matterTitles[1]);
    expect(DemoCorpus.matterTitleProcedural, DemoCorpus.matterTitles[2]);
    expect(DemoCorpus.matterTitleFamily, DemoCorpus.matterTitles[3]);
    expect(DemoCorpus.matterTitleStartup, DemoCorpus.matterTitles[4]);
  });

  test('maps every matter id to its title', () {
    expect(DemoCorpus.matterTitlesById, <String, String>{
      'matter-1': 'Demo acquisition review',
      'matter-2': 'Commercial lease consultation',
      'matter-3': 'Procedural review matter',
      'matter-4': 'Family status consultation',
      'matter-5': 'Startup formation advisory',
    });
    expect(DemoCorpus.matterTitlesById.keys.toList(), DemoCorpus.matterIds);
    expect(
      DemoCorpus.matterTitlesById.values.toList(),
      DemoCorpus.matterTitles,
    );
  });
}
