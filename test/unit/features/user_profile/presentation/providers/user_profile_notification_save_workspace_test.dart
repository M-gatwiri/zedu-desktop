import 'dart:async';

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

NotificationPreferences _prefs(NotificationMode mode) =>
    NotificationPreferences.empty().copyWith(mode: mode);

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(_prefs(NotificationMode.none));
  });

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
    when(
      () => repo.getOrganization(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    // Every workspace's saved choice is "all messages".
    when(
      () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
    ).thenAnswer((_) async => Success(_prefs(NotificationMode.allMessages)));
  });

  tearDown(() async => locator.reset());

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(_Workspaces.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(userProfileNotifierProvider, (_, _) {});
    return container;
  }

  test(
    'a notification save for workspace A does not overwrite workspace B',
    () async {
      final save = Completer<Result<NotificationPreferences>>();
      when(
        () => repo.updateNotificationPreferences(
          orgId: 'A',
          preferences: any(named: 'preferences'),
        ),
      ).thenAnswer((_) => save.future);
      final container = newContainer();
      await pumpEventQueue();

      final pending = container
          .read(userProfileNotifierProvider.notifier)
          .updateNotificationPreferences(_prefs(NotificationMode.none));

      // The user switches to workspace B while the save is in flight, and
      // B's own preferences (all messages) load.
      (container.read(workspaceProvider.notifier) as _Workspaces).select('B');
      await pumpEventQueue();
      expect(
        container.read(userProfileNotifierProvider).notifications?.mode,
        NotificationMode.allMessages,
      );

      save.complete(Success(_prefs(NotificationMode.none)));
      await pending;

      final shown = container.read(userProfileNotifierProvider);
      expect(
        shown.notifications?.mode,
        NotificationMode.allMessages,
        reason: "workspace A's saved preferences must not show for B",
      );
      expect(
        shown.successMessage,
        isNull,
        reason: 'no "saved" message for a workspace that is no longer shown',
      );
      expect(shown.isSaving, isFalse);
    },
  );

  test('a save in the same workspace shows its result and message', () async {
    when(
      () => repo.updateNotificationPreferences(
        orgId: 'A',
        preferences: any(named: 'preferences'),
      ),
    ).thenAnswer((_) async => Success(_prefs(NotificationMode.none)));
    final container = newContainer();
    await pumpEventQueue();

    await container
        .read(userProfileNotifierProvider.notifier)
        .updateNotificationPreferences(_prefs(NotificationMode.none));

    final shown = container.read(userProfileNotifierProvider);
    expect(shown.notifications?.mode, NotificationMode.none);
    expect(shown.successMessage, isNotNull);
    expect(shown.isSaving, isFalse);
  });
}
