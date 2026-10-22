import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/discovery/data/fake_attorney_gateway.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';

void main() {
  group('FakeAttorneyGateway.fetchAttorneys (AC-1)', () {
    test('returns the fixed synthetic list, deterministic per call', () async {
      final FakeAttorneyGateway gateway = FakeAttorneyGateway();

      final List<Attorney>? first =
          (await gateway.fetchAttorneys()).valueOrNull;
      final List<Attorney>? second =
          (await gateway.fetchAttorneys()).valueOrNull;

      // Same values on every call — no wall-clock or random dependence.
      expect(first, FakeAttorneyGateway.syntheticAttorneys);
      expect(second, first);
      expect(first, hasLength(5));
    });

    test('profiles carry only non-PII fields (D-A4 shape)', () async {
      final FakeAttorneyGateway gateway = FakeAttorneyGateway();

      final List<Attorney> attorneys =
          (await gateway.fetchAttorneys()).valueOrNull!;

      // Every synthetic profile exposes the D-A4 surface: id / name /
      // practice area / locale / bio. The string forms must never render
      // contact or credential shapes (no email/phone/address).
      for (final Attorney attorney in attorneys) {
        expect(attorney.id, isNotEmpty);
        expect(attorney.name, isNotEmpty);
        expect(attorney.practiceArea, isA<PracticeArea>());
        expect(attorney.locale, isNotEmpty);
        expect(attorney.bio, isNotEmpty);
        expect(attorney.toString(), isNot(contains('@')));
      }
    });

    test('covers every practice area in the filter set', () async {
      final FakeAttorneyGateway gateway = FakeAttorneyGateway();

      final List<Attorney> attorneys =
          (await gateway.fetchAttorneys()).valueOrNull!;

      // The search surface's area chips must each have at least one profile
      // behind them, or a filter would dead-end into an always-empty list.
      for (final PracticeArea area in PracticeArea.values) {
        expect(
          attorneys.where((Attorney a) => a.practiceArea == area),
          isNotEmpty,
          reason: 'no synthetic profile for $area',
        );
      }
    });

    test('synthetic ids are deliberately non-UUIDs (design §2)', () async {
      final FakeAttorneyGateway gateway = FakeAttorneyGateway();

      final List<Attorney> attorneys =
          (await gateway.fetchAttorneys()).valueOrNull!;

      for (final Attorney attorney in attorneys) {
        expect(attorney.id, startsWith('atty-'));
        expect(attorney.hasRealId, isFalse);
      }
    });
  });

  group('FakeAttorneyGateway query + detail', () {
    test('fetchAttorneys narrows by name, city, and specialty', () async {
      final FakeAttorneyGateway gateway = FakeAttorneyGateway();

      expect(
        (await gateway.fetchAttorneys(
          query: 'layla',
        )).valueOrNull!.map((Attorney a) => a.id),
        <String>['atty-1'],
      );
      expect(
        (await gateway.fetchAttorneys(
          query: 'alexandria',
        )).valueOrNull!.map((Attorney a) => a.id),
        <String>['atty-2'],
      );
      expect(
        (await gateway.fetchAttorneys(
          query: 'family',
        )).valueOrNull!.map((Attorney a) => a.id),
        <String>['atty-4'],
      );
    });

    test('fetchAttorney returns the matching row by id', () async {
      final FakeAttorneyGateway gateway = FakeAttorneyGateway();

      final Attorney attorney = (await gateway.fetchAttorney(
        'atty-3',
      )).valueOrNull!;

      expect(attorney.name, 'Sara Khalil');
    });

    test('fetchAttorney maps an unknown id to attorney_not_found', () async {
      final FakeAttorneyGateway gateway = FakeAttorneyGateway();

      final Result<Attorney> result = await gateway.fetchAttorney('no-such');

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'attorney_not_found');
    });
  });
}
