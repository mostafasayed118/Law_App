import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';

void main() {
  group('FakeMatterGateway.fetchMatters (AC-1)', () {
    test('returns the fixed synthetic list, deterministic per call', () async {
      final FakeMatterGateway gateway = FakeMatterGateway();

      final List<Matter>? first = (await gateway.fetchMatters()).valueOrNull;
      final List<Matter>? second = (await gateway.fetchMatters()).valueOrNull;

      // Same values on every call — no wall-clock or random dependence.
      expect(first, FakeMatterGateway.syntheticMatters);
      expect(second, first);
      expect(first, hasLength(5));
    });

    test('matters carry only non-PII fields (D-M4 shape)', () async {
      final FakeMatterGateway gateway = FakeMatterGateway();

      final List<Matter> matters = (await gateway.fetchMatters()).valueOrNull!;

      // Every synthetic matter exposes the D-M4 surface: id / generic demo
      // title / practice area / lifecycle status / assigned-attorney display
      // name / created date. The string forms must never render contact or
      // client-identity shapes (no email/phone/address).
      for (final Matter matter in matters) {
        expect(matter.id, isNotEmpty);
        expect(matter.title, isNotEmpty);
        expect(matter.practiceArea, isA<PracticeArea>());
        expect(matter.status, isA<MatterStatus>());
        expect(matter.assignedAttorneyName, isNotEmpty);
        expect(matter.toString(), isNot(contains('@')));
      }
    });

    test('covers every lifecycle status in the filter set', () async {
      final FakeMatterGateway gateway = FakeMatterGateway();

      final List<Matter> matters = (await gateway.fetchMatters()).valueOrNull!;

      // The list surface's status chips must each have at least one matter
      // behind them, or a filter would dead-end into an always-empty list.
      for (final MatterStatus status in MatterStatus.values) {
        expect(
          matters.where((Matter m) => m.status == status),
          isNotEmpty,
          reason: 'no synthetic matter for $status',
        );
      }
    });
  });
}
