import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/matters/domain/matter.dart';

void main() {
  group('MatterStatus (D-M4 pin)', () {
    test('pins the lifecycle status set', () {
      expect(MatterStatus.values, <MatterStatus>[
        MatterStatus.open,
        MatterStatus.active,
        MatterStatus.closed,
      ]);
    });
  });

  group('Matter VO (D-M4 shape)', () {
    test('is equatable on its synthetic preview fields', () {
      final DateTime created = DateTime.utc(2026, 7, 12);
      final Matter a = _matter(created: created);
      final Matter b = _matter(created: created);
      final Matter c = Matter(
        id: 'matter-2',
        title: 'Other demo matter',
        practiceArea: PracticeArea.civil,
        status: MatterStatus.open,
        assignedAttorneyName: 'Omar Farouk',
        createdAt: created,
      );

      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });
}

Matter _matter({required DateTime created}) => Matter(
  id: 'matter-1',
  title: 'Demo acquisition review',
  practiceArea: PracticeArea.corporate,
  status: MatterStatus.active,
  assignedAttorneyName: 'Layla Mansour',
  createdAt: created,
);
