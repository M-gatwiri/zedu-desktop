import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockRepo extends Mock implements UserProfileRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

Workspace _ws(String id) => Workspace(id: id, name: 'WS $id', avatar: '');

class _Workspaces extends WorkspaceNotifier {
  @override
  WorkspaceState build() => WorkspaceState(selectedWorkspace: _ws('A'));

  void select(String id) => state = state.copyWith(selectedWorkspace: _ws(id));
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
    when(() => repo.getSecuritySessions()).thenAnswer((_) => failed());
    when(() => repo.getRolesAndPermissions()).thenAnswer((_) => failed());
    when(() => repo.getBillingInfo()).thenAnswer((_) => failed());
    when(
      () => repo.getTeamMembers(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    // Workspace A loads fine; workspace B's organisation and notification
    // requests fail.
    when(() => repo.getOrganization(orgId: 'A')).thenAnswer(
      (_) async => const Success(
        OrganizationProfile(
          id: 'A',
          name: 'Org A',
          natureOfBusiness: 'Design',
          country: 'Nigeria',
        ),
      ),
    );
    when(() => repo.getOrganization(orgId: 'B')).thenAnswer((_) => failed());
    when(() => repo.getNotificationPreferences(orgId: 'A')).thenAnswer(
      (_) async => Success(
        NotificationPreferences.empty().copyWith(mode: NotificationMode.none),
      ),
    );
    when(
      () => repo.getNotificationPreferences(orgId: 'B'),
    ).thenAnswer((_) => failed());
  });

  tearDown(() async => locator.reset());

  test(
    'switching to a workspace whose data fails to load does not keep the previous workspace data',
    () async {
      final container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repo),
          workspaceProvider.overrideWith(_Workspaces.new),
        ],
      );
      addTearDown(container.dispose);
      container.listen(userProfileNotifierProvider, (_, _) {});
      await pumpEventQueue();
      expect(
        container.read(userProfileNotifierProvider).organization?.name,
        'Org A',
      );

      (container.read(workspaceProvider.notifier) as _Workspaces).select('B');
      await pumpEventQueue();

      final state = container.read(userProfileNotifierProvider);
      expect(state.error, isNotNull); // B's load did fail
      expect(
        state.organization,
        isNull,
        reason: 'workspace B must not show (or save over) workspace A\'s org',
      );
      expect(
        state.notifications,
        isNull,
        reason: "workspace A's notification choices must not show for B",
      );
    },
  );

  test(
    'a failed reload of the same workspace keeps what is already on screen',
    () async {
      var reloads = 0;
      when(() => repo.getOrganization(orgId: 'A')).thenAnswer((_) async {
        if (reloads++ == 0) {
          return const Success(
            OrganizationProfile(
              id: 'A',
              name: 'Org A',
              natureOfBusiness: 'Design',
              country: 'Nigeria',
            ),
          );
        }
        return const Failure<OrganizationProfile>(
          ApiFailure(message: 'unavailable'),
        );
      });
      final container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repo),
          workspaceProvider.overrideWith(_Workspaces.new),
        ],
      );
      addTearDown(container.dispose);
      container.listen(userProfileNotifierProvider, (_, _) {});
      await pumpEventQueue();
      expect(
        container.read(userProfileNotifierProvider).organization?.name,
        'Org A',
      );

      await container.read(userProfileNotifierProvider.notifier).load();

      final state = container.read(userProfileNotifierProvider);
      expect(state.error, isNotNull);
      expect(state.organization?.name, 'Org A');
      expect(state.notifications?.mode, NotificationMode.none);
    },
  );
}
