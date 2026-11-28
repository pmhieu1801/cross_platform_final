import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/data/local_avatar_repository.dart';
import 'package:final_note/features/auth/domain/avatar_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AvatarStore implements SyncedAvatarStore {
  final _records = <String, AvatarImage?>{};
  bool failWrites = false;

  @override
  Future<({bool initialized, AvatarImage? image})> load(String uid) async =>
      (initialized: _records.containsKey(uid), image: _records[uid]);

  @override
  Future<AvatarImage> save(String uid, AvatarImage image) async {
    if (failWrites) throw StateError('Offline');
    _records[uid] = image;
    return image;
  }

  @override
  Future<void> reset(String uid) async {
    if (failWrites) throw StateError('Offline');
    _records[uid] = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer signedInAs(String uid, _AvatarStore store) {
    final account = AccountSession(uid);
    final container = ProviderContainer(
      overrides: [
        accountSessionProvider.overrideWithValue(account),
        syncedAvatarStoreProvider.overrideWith((_) async => store),
      ],
    );
    container.listen(accountCustomAvatarProvider, (_, _) {});
    addTearDown(() {
      account.close();
      container.dispose();
    });
    return container;
  }

  test(
    'cross-device avatar and reset take precedence over a legacy avatar',
    () async {
      final store = _AvatarStore();
      final local = LocalAvatarRepository();
      final legacy = LocalAvatarRepository.sampleAvatars.first.bytes;
      final updated = LocalAvatarRepository.sampleAvatars.last.bytes;
      await local.upload(
        expectedUid: 'owner',
        image: await local.validator.validate(legacy),
      );

      final first = signedInAs('owner', store);
      expect(
        (await first.read(accountCustomAvatarProvider.future))?.bytes,
        orderedEquals(legacy),
      );
      final actions = first.read(accountCustomAvatarProvider.notifier);
      expect(await actions.pickAndSaveAvatar(bytes: updated), isNull);
      final saved = first.read(accountCustomAvatarProvider).value!;
      expect(saved.contentType, 'image/png');

      final second = signedInAs('owner', store);
      final other = signedInAs('other', store);
      expect(
        (await second.read(accountCustomAvatarProvider.future))?.bytes,
        orderedEquals(saved.bytes),
      );
      expect(await other.read(accountCustomAvatarProvider.future), isNull);
      expect(await actions.removeAvatar(), isNull);
      second.invalidate(accountCustomAvatarProvider);
      expect(await second.read(accountCustomAvatarProvider.future), isNull);
      expect((await local.loadAvatar('owner'))?.bytes, orderedEquals(legacy));
    },
  );

  test('failed cloud writes keep the last confirmed avatar', () async {
    final store = _AvatarStore();
    final container = signedInAs('owner', store);
    final original = LocalAvatarRepository.sampleAvatars.first.bytes;
    final replacement = LocalAvatarRepository.sampleAvatars.last.bytes;
    await container.read(accountCustomAvatarProvider.future);
    final actions = container.read(accountCustomAvatarProvider.notifier);
    expect(await actions.pickAndSaveAvatar(bytes: original), isNull);
    final saved = container.read(accountCustomAvatarProvider).value!;

    store.failWrites = true;
    expect(await actions.pickAndSaveAvatar(bytes: replacement), isNotNull);
    expect(await actions.removeAvatar(), isNotNull);
    expect(
      container.read(accountCustomAvatarProvider).value?.bytes,
      orderedEquals(saved.bytes),
    );
  });
}
