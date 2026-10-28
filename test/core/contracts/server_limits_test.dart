import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/contracts/server_limits.dart';

void main() {
  test('server limits match the database contract', () {
    expect(kTitleMaxLength, 160);
    expect(kDescriptionMaxLength, 4000);
    expect(kDecisionNoteMaxLength, 2000);
    expect(kAttorneyNameMaxLength, 120);
    expect(kAttorneyBioMaxLength, 2000);
    expect(kBookingTopicMaxLength, 2000);
    expect(kResearchFindingsMax, 12);
  });
}
