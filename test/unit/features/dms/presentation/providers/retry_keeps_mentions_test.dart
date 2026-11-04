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
  test('retrying a failed message sends its mentions again', () async {
    final repo = _MockDmRepository();
    when(
      () => repo.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    var calls = 0;
    when(
      () => repo.sendMessage(
        any(),
        any(),
        media: any(named: 'media'),
        mentions: any(named: 'mentions'),
        isChannel: any(named: 'isChannel'),
      ),
    ).thenAnswer((_) async {
      if (calls++ == 0) throw Exception('offline');
      return 't-1';
    });

    final container = ProviderContainer(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repo),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(chatHistoryProvider('ch-1'), (_, _) {});
    addTearDown(sub.close);
    final notifier = sub.read();
    await pumpEventQueue();

    final mentions = [
      {'user_id': 'u2', 'username': 'ada'},
    ];
    await notifier.sendMessage('hi @ada', mentions: mentions);
    expect(notifier.messages.first['status'], 'failed');

    await notifier.retryMessage(notifier.messages.first['id'] as String);

    // The first call (the failed send) and the retry must both carry them.
    verify(
      () => repo.sendMessage(
        'ch-1',
        'hi @ada',
        media: any(named: 'media'),
        mentions: mentions,
        isChannel: any(named: 'isChannel'),
      ),
    ).called(2);
  });
}
