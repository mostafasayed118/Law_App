/// Screenshot-only research fixture seam.
///
/// The portfolio research screenshot must show a populated, clearly synthetic
/// run history. This helper is called ONLY by screenshot capture/tests; it must
/// never be reachable from the app's normal runtime path.
///
/// RED state: the seam exists but seeds nothing, so the capture test fails on
/// the "no runs yet" empty state. The fix commit implements it.
Future<void> seedScreenshotResearchFixture() async {}
