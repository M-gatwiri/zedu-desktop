import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeChatStorage extends Fake implements ChatStorageService {
  final List<(String, String)> appended = [];

  @override
  Future<void> appendMessage(String groupDmId, String message) async {
    appended.add((groupDmId, message));
  }
}

void main() {
  const member = TeamMember(
    id: 'm1',
    email: 'a@example.com',
    role: 'member',
    dateJoined: '2026-01-01',
    status: TeamMemberStatus.active,
  );

  late _FakeChatStorage storage;

  setUp(() => storage = _FakeChatStorage());

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: [chatStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  // Signing out calls ref.invalidate(groupDmProvider) and the same notifier is
  // reused for the next session, so work that finishes later must not land in
  // the new session.
  test('a createGroupDm started before sign-out does not add a group to the '
      'next session', () async {
    final container = newContainer();
    container.read(groupDmProvider);
    final pending = container.read(groupDmProvider.notifier).createGroupDm([
      member,
    ]);

    container.invalidate(groupDmProvider); // sign out
    expect(container.read(groupDmProvider), isEmpty);

    final result = await pending;

    expect(result, isA<Failure<GroupDM>>());
    expect(container.read(groupDmProvider), isEmpty);
  });

  test('a group created in the same session is added as before', () async {
    final container = newContainer();
    container.read(groupDmProvider);

    final result = await container.read(groupDmProvider.notifier).createGroupDm(
      [member],
    );

    expect(result, isA<Success<GroupDM>>());
    expect(container.read(groupDmProvider), hasLength(1));
  });

  test(
    'a message sent before sign-out is not saved for the next session',
    () async {
      final container = newContainer();
      container.read(groupDmProvider);
      final pending = container
          .read(groupDmProvider.notifier)
          .sendMessage('group-1', 'hello');

      container.invalidate(groupDmProvider); // sign out
      container.read(groupDmProvider);
      await pending;

      expect(storage.appended, isEmpty);
    },
  );

  test('a message sent in the same session is saved as before', () async {
    final container = newContainer();
    container.read(groupDmProvider);

    await container
        .read(groupDmProvider.notifier)
        .sendMessage('group-1', 'hello');

    expect(storage.appended, [('group-1', 'hello')]);
  });
}
