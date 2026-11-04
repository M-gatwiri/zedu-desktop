import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org-slug',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

void main() {
  testWidgets('polling does not add a second copy of a message just sent', (
    tester,
  ) async {
    final repo = _MockDmRepository();
    var sent = false;
    when(() => repo.getMessages(any(), page: any(named: 'page'))).thenAnswer(
      (_) async => sent
          ? [
              // The server lists the message under the thread id it returned
              // from the send request.
              {'id': 'thread-1', 'content': 'hello', 'user_id': 'user-1'},
            ]
          : <Map<String, dynamic>>[],
    );
    when(
      () => repo.sendMessage(
        any(),
        any(),
        media: any(named: 'media'),
        mentions: any(named: 'mentions'),
        isChannel: any(named: 'isChannel'),
      ),
    ).thenAnswer((_) async {
      sent = true;
      return 'thread-1';
    });

    final container = ProviderContainer(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repo),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      ],
    );
    final sub = container.listen(chatHistoryProvider('ch-1'), (_, _) {});
    final notifier = sub.read();
    await tester.pump();

    await notifier.sendMessage('hello');
    expect(notifier.messages, hasLength(1));

    // One poll interval (10 seconds) passes and the poll fetches the message.
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();

    expect(notifier.messages, hasLength(1));

    // Dispose here so the notifier's polling timer is cancelled before the
    // test ends.
    sub.close();
    container.dispose();
  });
}
