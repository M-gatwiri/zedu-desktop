import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockRepo extends Mock implements UserProfileRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

class _FakeAuth extends AuthNotifier {
  int logouts = 0;

  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);

  @override
  Future<void> logout() async {
    logouts++;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

class _Workspaces extends WorkspaceNotifier {
  @override
  WorkspaceState build() => WorkspaceState(
    selectedWorkspace: Workspace(id: 'A', name: 'WS A', avatar: ''),
  );
}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    final storage = _MockStorage();
    locator.registerSingleton<SecureStorageService>(storage);
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    Future<Result<T>> failed<T>() async =>
        Failure<T>(const ApiFailure(message: 'unavailable'));
    when(() => repo.getAccount()).thenAnswer((_) => failed());
    when(
      () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(() => repo.getSecuritySessions()).thenAnswer((_) => failed());
    when(
      () => repo.getOrganization(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(
      () => repo.getTeamMembers(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(() => repo.getRolesAndPermissions()).thenAnswer((_) => failed());
    when(() => repo.getBillingInfo()).thenAnswer((_) => failed());
  });

  tearDown(() async => locator.reset());

  ProviderContainer containerWith(_FakeAuth auth) {
    final container = ProviderContainer(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(_Workspaces.new),
        authNotifierProvider.overrideWith(() => auth),
      ],
    );
    addTearDown(container.dispose);
    container.listen(userProfileNotifierProvider, (_, _) {});
    container.listen(authNotifierProvider, (_, _) {});
    return container;
  }

  test('deleting the account signs the user out', () async {
    when(
      () => repo.deleteAccount(),
    ).thenAnswer((_) async => const Success(null));
    final auth = _FakeAuth();
    final container = containerWith(auth);
    await pumpEventQueue();

    await container.read(userProfileNotifierProvider.notifier).deleteAccount();

    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
      reason: 'a deleted account must not stay signed in',
    );
    expect(auth.logouts, 1);
  });

  test(
    'a failed deletion keeps the user signed in and shows the error',
    () async {
      when(() => repo.deleteAccount()).thenAnswer(
        (_) async => Failure<void>(const ApiFailure(message: 'not allowed')),
      );
      final auth = _FakeAuth();
      final container = containerWith(auth);
      await pumpEventQueue();

      await container
          .read(userProfileNotifierProvider.notifier)
          .deleteAccount();

      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.authenticated,
      );
      expect(auth.logouts, 0);
      expect(container.read(userProfileNotifierProvider).error, isNotNull);
    },
  );
}
