import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';

void main() {
  group('PracticeArea (D-A5 pin)', () {
    test('exposes exactly the four dashboard practice areas', () {
      // The discovery surface reuses the home dashboard's practice-area l10n
      // keys (areaCorporate … areaFamily). This pin fails loudly if an area is
      // ever added without an explicit owner decision (same discipline as the
      // BookingCategory G2 pin).
      expect(PracticeArea.values, <PracticeArea>[
        PracticeArea.corporate,
        PracticeArea.civil,
        PracticeArea.criminal,
        PracticeArea.family,
      ]);
      expect(PracticeArea.values.length, 4);
    });
  });

  group('Attorney value semantics', () {
    test('equates on all profile fields (Equatable props)', () {
      final Attorney first = Attorney(
        id: 'atty-1',
        name: 'Layla Mansour',
        practiceArea: PracticeArea.corporate,
        locale: 'EN / AR',
        bio: 'Corporate transactions and governance counsel.',
      );
      final Attorney second = Attorney(
        id: 'atty-1',
        name: 'Layla Mansour',
        practiceArea: PracticeArea.corporate,
        locale: 'EN / AR',
        bio: 'Corporate transactions and governance counsel.',
      );
      final Attorney other = Attorney(
        id: 'atty-2',
        name: 'Omar Farouk',
        practiceArea: PracticeArea.civil,
        locale: 'EN / AR',
        bio: 'Civil litigation and contracts.',
      );

      expect(second, first);
      expect(other, isNot(first));
    });

    test('carries no contact or credential fields (D-A4 shape)', () {
      const Attorney attorney = Attorney(
        id: 'atty-1',
        name: 'Layla Mansour',
        practiceArea: PracticeArea.corporate,
        locale: 'EN / AR',
        bio: 'Corporate transactions and governance counsel.',
      );

      // The type has exactly the D-A4 fields: id / name / practice area /
      // locale / bio. There is no phone, email, address, or credentials
      // property to read — asserting the string form never renders such
      // shapes guards the honesty boundary at the value level too.
      expect(attorney.toString(), isNot(contains('@')));
      expect(attorney.toString(), isNot(contains('phone')));
      expect(attorney.toString(), isNot(contains('email')));
    });
  });
}
