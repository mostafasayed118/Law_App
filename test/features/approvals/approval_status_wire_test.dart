import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';

void main() {
  test('denied maps to rejected on the wire and back', () {
    expect(approvalStatusToWire(ApprovalStatus.denied), 'rejected');
    expect(approvalStatusFromWire('rejected'), ApprovalStatus.denied);
    for (final status in ApprovalStatus.values) {
      expect(approvalStatusFromWire(approvalStatusToWire(status)), status);
    }
  });
}
