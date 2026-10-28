import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/data/discovery/supabase_attorney_api.dart';
import 'package:legalhub/features/discovery/data/supabase_attorney_gateway.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_admin_gateway.dart';

/// Hand-rolled fake of the [SupabaseAttorneyApi] seam: records every call and
/// answers with canned rows/ids or a typed exception.
class _StubSupabaseAttorneyApi implements SupabaseAttorneyApi {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  Map<String, dynamic>? row;
  String createdId = '11111111-1111-4111-8111-111111111111';
  SupabaseAttorneyException? error;

  final List<Map<String, dynamic>> listCalls = <Map<String, dynamic>>[];
  final List<String> getCalls = <String>[];
  final List<Map<String, dynamic>> createCalls = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> updateCalls = <Map<String, dynamic>>[];
  final List<String> deactivateCalls = <String>[];

  void _failIfSet() {
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listAttorneys({
    String query = '',
    bool includeInactive = false,
    int limit = 50,
  }) async {
    listCalls.add(<String, dynamic>{
      'query': query,
      'includeInactive': includeInactive,
      'limit': limit,
    });
    _failIfSet();
    return rows;
  }

  @override
  Future<Map<String, dynamic>> getAttorney(String id) async {
    getCalls.add(id);
    _failIfSet();
    return row ??
        (throw const SupabaseAttorneyException(
          kind: SupabaseAttorneyFailureKind.notFound,
          message: 'Attorney profile not found.',
        ));
  }

  @override
  Future<String> createAttorney({
    required String displayName,
    required List<String> specialties,
    required List<String> languages,
    String? headline,
    String? bio,
    String? city,
    int? yearsExperience,
    String? avatarUrl,
  }) async {
    createCalls.add(<String, dynamic>{
      'displayName': displayName,
      'specialties': specialties,
      'languages': languages,
      'headline': headline,
      'bio': bio,
      'city': city,
      'yearsExperience': yearsExperience,
      'avatarUrl': avatarUrl,
    });
    _failIfSet();
    return createdId;
  }

  @override
  Future<void> updateAttorney(
    String id, {
    required String displayName,
    required List<String> specialties,
    required List<String> languages,
    String? headline,
    String? bio,
    String? city,
    int? yearsExperience,
    String? avatarUrl,
  }) async {
    updateCalls.add(<String, dynamic>{
      'id': id,
      'displayName': displayName,
      'specialties': specialties,
      'languages': languages,
      'headline': headline,
      'bio': bio,
      'city': city,
      'yearsExperience': yearsExperience,
      'avatarUrl': avatarUrl,
    });
    _failIfSet();
  }

  @override
  Future<void> deactivateAttorney(String id) async {
    deactivateCalls.add(id);
    _failIfSet();
  }
}

Map<String, dynamic> _row({
  String id = '11111111-1111-4111-8111-111111111111',
  String name = 'Layla Mansour',
  String? headline = 'Corporate and governance counsel',
  String? bio = 'Corporate transactions.',
  String? city = 'Cairo',
  List<String> specialties = const <String>['corporate'],
  List<String> languages = const <String>['en', 'ar'],
  int? years = 12,
  String status = 'active',
}) => <String, dynamic>{
  'id': id,
  'display_name': name,
  'headline': headline,
  'bio': bio,
  'city': city,
  'specialties': specialties,
  'languages': languages,
  'years_experience': years,
  'status': status,
};

void main() {
  late _StubSupabaseAttorneyApi api;
  late SupabaseAttorneyGateway gateway;

  setUp(() {
    api = _StubSupabaseAttorneyApi();
    gateway = SupabaseAttorneyGateway(api);
  });

  group('row → Attorney mapping', () {
    test(
      'maps a full row, projects specialties and the display locale',
      () async {
        api.rows = <Map<String, dynamic>>[_row()];

        final Result<List<Attorney>> result = await gateway.fetchAttorneys();

        expect(result.isSuccess, isTrue);
        final Attorney attorney = result.valueOrNull!.single;
        expect(attorney.id, '11111111-1111-4111-8111-111111111111');
        expect(attorney.name, 'Layla Mansour');
        expect(attorney.headline, 'Corporate and governance counsel');
        expect(attorney.city, 'Cairo');
        expect(attorney.practiceArea, PracticeArea.corporate);
        expect(attorney.locale, 'EN / AR');
        expect(attorney.specialties, <String>['corporate']);
        expect(attorney.languages, <String>['en', 'ar']);
        expect(attorney.yearsExperience, 12);
        expect(attorney.isActive, isTrue);
        expect(attorney.hasRealId, isTrue);
      },
    );

    test('leaves practiceArea null for an unrecognized specialty', () async {
      api.rows = <Map<String, dynamic>>[
        _row(specialties: <String>['arbitration']),
      ];

      final Attorney attorney =
          (await gateway.fetchAttorneys()).valueOrNull!.single;

      expect(attorney.practiceArea, isNull);
    });

    test('maps an inactive row to isActive false (admin listing)', () async {
      api.rows = <Map<String, dynamic>>[_row(status: 'inactive')];

      final Attorney attorney = (await gateway.fetchAll()).valueOrNull!.single;

      expect(attorney.isActive, isFalse);
    });

    test('an unknown status fails the read loudly', () async {
      api.rows = <Map<String, dynamic>>[_row(status: 'archived')];

      final Result<List<Attorney>> result = await gateway.fetchAttorneys();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'attorney_read_failed');
    });
  });

  group('query passthrough', () {
    test(
      'fetchAttorneys sends the query, active-only, default limit',
      () async {
        await gateway.fetchAttorneys(query: 'civil');

        expect(api.listCalls.single, <String, dynamic>{
          'query': 'civil',
          'includeInactive': false,
          'limit': 50,
        });
      },
    );

    test('fetchAll requests inactive rows with the admin cap', () async {
      await gateway.fetchAll();

      expect(api.listCalls.single, <String, dynamic>{
        'query': '',
        'includeInactive': true,
        'limit': 100,
      });
    });

    test('fetchAttorney passes the id through', () async {
      api.row = _row();

      final Result<Attorney> result = await gateway.fetchAttorney(
        '11111111-1111-4111-8111-111111111111',
      );

      expect(result.isSuccess, isTrue);
      expect(api.getCalls, <String>['11111111-1111-4111-8111-111111111111']);
    });

    test('a missing profile maps to attorney_not_found', () async {
      final Result<Attorney> result = await gateway.fetchAttorney('missing');

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'attorney_not_found');
    });
  });

  group('admin writes', () {
    const AttorneyDraft draft = AttorneyDraft(
      displayName: 'New Attorney',
      headline: 'Headline',
      city: 'Giza',
      specialties: <String>['family'],
      languages: <String>['ar'],
      yearsExperience: 3,
    );

    test('create sends the draft and returns the server id', () async {
      final Result<String> result = await gateway.create(draft);

      expect(result.valueOrNull, api.createdId);
      expect(api.createCalls.single, <String, dynamic>{
        'displayName': 'New Attorney',
        'specialties': <String>['family'],
        'languages': <String>['ar'],
        'headline': 'Headline',
        'bio': null,
        'city': 'Giza',
        'yearsExperience': 3,
        'avatarUrl': null,
      });
    });

    test('update and deactivate pass the id and fields through', () async {
      final Result<void> updateResult = await gateway.update('a-1', draft);
      final Result<void> deactivateResult = await gateway.deactivate('a-1');

      expect(updateResult.isSuccess, isTrue);
      expect(deactivateResult.isSuccess, isTrue);
      expect(api.updateCalls.single['id'], 'a-1');
      expect(api.updateCalls.single['displayName'], 'New Attorney');
      expect(api.deactivateCalls, <String>['a-1']);
    });

    test('a denied write keeps the denied kind', () async {
      api.error = const SupabaseAttorneyException(
        kind: SupabaseAttorneyFailureKind.denied,
        message: 'permission denied',
      );

      final Result<String> result = await gateway.create(draft);

      expect(result.errorOrNull?.code, 'attorney_write_denied');
      expect(result.errorOrNull?.kind, AppErrorKind.denied);
    });

    test('a validation refusal maps to attorney_write_invalid', () async {
      api.error = const SupabaseAttorneyException(
        kind: SupabaseAttorneyFailureKind.validation,
        message: 'display name is required',
      );

      final Result<void> result = await gateway.deactivate('a-1');

      expect(result.errorOrNull?.code, 'attorney_write_invalid');
    });
  });

  group('failure mapping', () {
    test('a denied read maps to the denied AppError kind', () async {
      api.error = const SupabaseAttorneyException(
        kind: SupabaseAttorneyFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<Attorney>> result = await gateway.fetchAttorneys();

      expect(result.errorOrNull?.code, 'attorney_read_denied');
      expect(result.errorOrNull?.kind, AppErrorKind.denied);
    });

    test('a provider outage maps to the unavailable kind', () async {
      api.error = const SupabaseAttorneyException(
        kind: SupabaseAttorneyFailureKind.providerUnavailable,
        message: 'down',
      );

      final Result<List<Attorney>> result = await gateway.fetchAttorneys();

      expect(result.errorOrNull?.code, 'attorney_read_unavailable');
      expect(result.errorOrNull?.kind, AppErrorKind.unavailable);
    });

    test('an empty list is a success, not an error', () async {
      final Result<List<Attorney>> result = await gateway.fetchAttorneys();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });
}
