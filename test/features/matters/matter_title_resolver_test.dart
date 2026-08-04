import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_title_resolver.dart';

void main() {
  group('resolveMatterByTitle (Phase 12 D-C3)', () {
    test('resolves the matter whose title matches the matterRef exactly', () {
      final Matter? resolved = resolveMatterByTitle(
        _matters,
        'Demo acquisition review',
      );

      expect(resolved?.id, 'matter-1');
    });

    test('returns null when no synthetic matter title matches', () {
      expect(
        resolveMatterByTitle(_matters, 'No such synthetic matter'),
        isNull,
      );
    });

    test('is title-keyed and exact — never matches on ids or partial text', () {
      // Ids are never the key (D-W2/D-C3): matching against an id or a
      // partial title must fail even though the title contains it.
      expect(resolveMatterByTitle(_matters, 'matter-1'), isNull);
      expect(resolveMatterByTitle(_matters, 'Demo acquisition'), isNull);
      expect(resolveMatterByTitle(_matters, ''), isNull);
    });

    test('returns the first matching matter when titles collide', () {
      final Matter first = _matters[0];
      final List<Matter> duplicate = <Matter>[first, _matters[1]];

      expect(resolveMatterByTitle(duplicate, 'Demo acquisition review'), first);
    });
  });
}

/// The fixed synthetic matter list (mirrors FakeMatterGateway's titles).
final List<Matter> _matters = <Matter>[
  Matter(
    id: 'matter-1',
    title: 'Demo acquisition review',
    practiceArea: PracticeArea.corporate,
    status: MatterStatus.active,
    assignedAttorneyName: 'Layla Mansour',
    createdAt: DateTime.utc(2026, 7, 12),
  ),
  Matter(
    id: 'matter-2',
    title: 'Commercial lease consultation',
    practiceArea: PracticeArea.civil,
    status: MatterStatus.open,
    assignedAttorneyName: 'Omar Farouk',
    createdAt: DateTime.utc(2026, 7, 18),
  ),
];
