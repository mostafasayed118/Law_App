import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/storage/data/fake_storage_gateway.dart';
import 'package:legalhub/features/storage/domain/file_metadata.dart';

void main() {
  group('FakeStorageGateway.fetchFiles (D-STR7)', () {
    test('returns the fixed synthetic list, deterministic per call', () async {
      final FakeStorageGateway gateway = FakeStorageGateway();

      final List<FileMetadata>? first =
          (await gateway.fetchFiles()).valueOrNull;
      final List<FileMetadata>? second =
          (await gateway.fetchFiles()).valueOrNull;

      // Same values on every call — no wall-clock or random dependence.
      expect(first, FakeStorageGateway.syntheticFiles);
      expect(second, first);
      expect(first, hasLength(5));
    });

    test('scopes the list to one matter id', () async {
      final FakeStorageGateway gateway = FakeStorageGateway();

      final List<FileMetadata> files = (await gateway.fetchFiles(
        matterId: 'matter-1',
      )).valueOrNull!;

      expect(files, hasLength(1));
      expect(files.single.id, 'file-1');
      expect(files.single.matterId, 'matter-1');
    });

    test('files carry only non-PII metadata fields (D-STR3 shape)', () async {
      final FakeStorageGateway gateway = FakeStorageGateway();

      final List<FileMetadata> files =
          (await gateway.fetchFiles()).valueOrNull!;

      // Every synthetic file exposes the D-STR3 surface: id / generic demo
      // name / matter reference / mime type / byte size / storage path.
      // Metadata only — the string forms must never render contact or
      // client-identity shapes (no email/phone/address).
      for (final FileMetadata file in files) {
        expect(file.id, isNotEmpty);
        expect(file.name, isNotEmpty);
        expect(file.matterRef, isNotEmpty);
        expect(file.mimeType, isNotEmpty);
        expect(file.sizeBytes, greaterThanOrEqualTo(0));
        expect(file.storagePath, isNotEmpty);
        expect(file.toString(), isNot(contains('@')));
      }
    });

    test('every file references a known synthetic matter title (D-STR5)', () {
      final List<FileMetadata> files = FakeStorageGateway.syntheticFiles;

      // D-STR5 pin (the D-W2 discipline extended to files): each file's
      // matterRef is one of the known synthetic matter titles (the same set
      // Document.matterRef / MessageThread.matterRef use) — the per-matter
      // association must never read as a real case reference.
      const Set<String> knownMatterTitles = <String>{
        'Demo acquisition review',
        'Commercial lease consultation',
        'Procedural review matter',
        'Family status consultation',
        'Startup formation advisory',
      };
      for (final FileMetadata file in files) {
        expect(
          knownMatterTitles,
          contains(file.matterRef),
          reason: 'file ${file.id} references an unknown matter',
        );
      }
      // Every known matter has at least one synthetic file, so the per-matter
      // workspace view never dead-ends into an always-empty section for a
      // matter that exists in the demo roster.
      for (final String title in knownMatterTitles) {
        expect(
          files.where((FileMetadata f) => f.matterRef == title),
          isNotEmpty,
          reason: 'no synthetic file for $title',
        );
      }
    });

    test('storage paths follow the D-STR4 {org}/{matter}/{name} encoding', () {
      final List<FileMetadata> files = FakeStorageGateway.syntheticFiles;

      // The path is the metadata↔object link (single source of truth,
      // D-STR3/D-STR4): every demo path carries exactly two segments before
      // the filename and never a real-looking org/matter id.
      for (final FileMetadata file in files) {
        final List<String> segments = file.storagePath.split('/');
        expect(segments, hasLength(3), reason: file.storagePath);
        expect(segments[0], 'org-demo');
        expect(segments[1], startsWith('matter-'));
        expect(segments[2], isNotEmpty);
      }
    });

    test('no download affordance: the VO exposes no URL or content field', () {
      final List<FileMetadata> files = FakeStorageGateway.syntheticFiles;

      // D-STR9: the client surface is metadata-only by construction — the
      // storagePath is a key, never a link (no http/signed-URL shape).
      for (final FileMetadata file in files) {
        expect(file.storagePath, isNot(startsWith('http')));
        expect(file.storagePath, isNot(contains('?')));
      }
    });
  });

  group('FakeStorageGateway write/preview seams', () {
    test('uploadFile adds a metadata row with the selected name', () async {
      final FakeStorageGateway gateway = FakeStorageGateway();

      final Result<FileMetadata> result = await gateway.uploadFile(
        matterId: 'matter-1',
        name: 'new note.txt',
        mimeType: 'text/plain',
        sizeBytes: 12,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(result.isSuccess, isTrue);
      final FileMetadata uploaded = result.valueOrNull!;
      expect(uploaded.name, 'new note.txt');
      expect(uploaded.matterRef, 'Demo acquisition review');
      expect(uploaded.mimeType, 'text/plain');
      expect(uploaded.sizeBytes, 12);

      final List<FileMetadata> files =
          (await gateway.fetchFiles()).valueOrNull!;
      expect(files, hasLength(6));
      expect(files.last, uploaded);
    });

    test('createDownloadUrl returns a deterministic https URL', () async {
      final FakeStorageGateway gateway = FakeStorageGateway();
      const FileMetadata file = FileMetadata(
        id: 'file-1',
        name: 'Demo retainer scan',
        matterRef: 'Demo acquisition review',
        mimeType: 'application/pdf',
        sizeBytes: 12,
        storagePath: 'org-demo/matter-1/demo-retainer-scan.pdf',
      );

      final Result<Uri> first = await gateway.createDownloadUrl(file);
      final Result<Uri> second = await gateway.createDownloadUrl(file);

      expect(first.valueOrNull, second.valueOrNull);
      expect(first.valueOrNull?.scheme, 'https');
      expect(first.valueOrNull?.path, contains('file-1'));
    });
  });
}
