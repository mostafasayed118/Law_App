import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/matters/data/fake_matter_write_gateway.dart';
import 'package:legalhub/features/matters/domain/matter_write_gateway.dart';

void main() {
  group(
    'FakeMatterWriteGateway.createMatter (F-01 step 2 client swap, C-D3)',
    () {
      test('creates a matter and returns a deterministic id', () async {
        final FakeMatterWriteGateway gateway = FakeMatterWriteGateway();

        final Result<CreatedMatter> first = await gateway.createMatter(
          const CreateMatterRequest(
            organizationId: FakeMatterWriteGateway.demoOrganizationId,
            title: 'Demo acquisition review',
            practiceArea: PracticeArea.corporate,
          ),
        );
        final Result<CreatedMatter> second = await gateway.createMatter(
          const CreateMatterRequest(
            organizationId: FakeMatterWriteGateway.demoOrganizationId,
            title: 'Demo acquisition review',
            practiceArea: PracticeArea.corporate,
          ),
        );

        // Success carries the trimmed title + the requested area; ids are
        // deterministic (counter-based, never clock- or randomness-based).
        expect(first.isSuccess, isTrue);
        expect(first.valueOrNull!.title, 'Demo acquisition review');
        expect(first.valueOrNull!.practiceArea, PracticeArea.corporate);
        expect(second.valueOrNull!.id, isNot(first.valueOrNull!.id));
        expect(gateway.created, hasLength(2));
      });

      test(
        'refuses the fixture platform-owner id as an assignee (F2-D2)',
        () async {
          final FakeMatterWriteGateway gateway = FakeMatterWriteGateway();

          final Result<CreatedMatter> asClient = await gateway.createMatter(
            CreateMatterRequest(
              organizationId: FakeMatterWriteGateway.demoOrganizationId,
              title: 'Demo matter',
              practiceArea: PracticeArea.civil,
              assignedClientId: FakeMatterWriteGateway.platformOwnerId,
            ),
          );
          final Result<CreatedMatter> asAttorney = await gateway.createMatter(
            CreateMatterRequest(
              organizationId: FakeMatterWriteGateway.demoOrganizationId,
              title: 'Demo matter',
              practiceArea: PracticeArea.civil,
              assignedAttorneyId: FakeMatterWriteGateway.platformOwnerId,
            ),
          );

          // The owner refusal maps to the F2-D2 code, mirroring the RPC.
          expect(asClient.errorOrNull!.code, 'matter_write_owner_forbidden');
          expect(asAttorney.errorOrNull!.code, 'matter_write_owner_forbidden');
          expect(gateway.created, isEmpty);
        },
      );

      test('rejects a blank title (validation mirror)', () async {
        final FakeMatterWriteGateway gateway = FakeMatterWriteGateway();

        final Result<CreatedMatter> result = await gateway.createMatter(
          const CreateMatterRequest(
            organizationId: FakeMatterWriteGateway.demoOrganizationId,
            title: '   ',
            practiceArea: PracticeArea.family,
          ),
        );

        expect(result.errorOrNull!.code, 'matter_write_validation');
      });

      test('rejects a non-member assignee (F2-D4 mirror)', () async {
        final FakeMatterWriteGateway gateway = FakeMatterWriteGateway();

        final Result<CreatedMatter> result = await gateway.createMatter(
          CreateMatterRequest(
            organizationId: FakeMatterWriteGateway.demoOrganizationId,
            title: 'Demo matter',
            practiceArea: PracticeArea.family,
            assignedClientId: 'unknown-user-id',
          ),
        );

        expect(result.errorOrNull!.code, 'matter_write_assignee_invalid');
      });

      test('accepts only the demo org id (F2-D1 mirror)', () async {
        final FakeMatterWriteGateway gateway = FakeMatterWriteGateway();

        final Result<CreatedMatter> result = await gateway.createMatter(
          const CreateMatterRequest(
            organizationId: 'org-other',
            title: 'Demo matter',
            practiceArea: PracticeArea.criminal,
          ),
        );

        expect(result.errorOrNull!.code, 'matter_write_denied');
      });

      test('accepts an active roster member as an assignee', () async {
        final FakeMatterWriteGateway gateway = FakeMatterWriteGateway();

        final Result<CreatedMatter> result = await gateway.createMatter(
          CreateMatterRequest(
            organizationId: FakeMatterWriteGateway.demoOrganizationId,
            title: 'Demo matter',
            practiceArea: PracticeArea.corporate,
            assignedClientId: 'demo-user',
            assignedAttorneyId: 'demo-user',
          ),
        );

        expect(result.isSuccess, isTrue);
      });
    },
  );
}
