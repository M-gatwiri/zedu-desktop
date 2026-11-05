import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _Org extends Notifier<String> {
  @override
  String build() => 'org-1';

  void select(String orgId) => state = orgId;
}

final _orgProvider = NotifierProvider<_Org, String>(_Org.new);

class _FakePeopleRepository implements PeopleRepository {
  final requests = <(int, String)>[];
  bool failPage2 = false;
  final held = <String, Completer<Result<MembersPage>>>{};

  void hold(String orgId, int page) =>
      held['$orgId/$page'] = Completer<Result<MembersPage>>();

  @override
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) async {
    requests.add((page, search));
    if (held.containsKey('$orgId/$page')) {
      return held['$orgId/$page']!.future;
    }
    if (page == 2 && failPage2) {
      return const Failure(ApiFailure(message: 'offline'));
    }
    return Success(
      MembersPage(
        members: page == 1
            ? (orgId == 'org-1'
                ? const [
                    OrgMember(id: 'u-1', name: 'Ada'),
                    OrgMember(id: 'u-2', name: 'Grace'),
                  ]
                : const [
                    OrgMember(id: 'u-b1', name: 'Bob'),
                  ])
            // u-2 again: pages can overlap when someone joins meanwhile.
            : const [
                OrgMember(id: 'u-2', name: 'Grace'),
                OrgMember(id: 'u-3', name: 'Linus'),
              ],
        currentPage: page,
        totalPages: 2,
        totalItems: 3,
      ),
    );
  }
}

void main() {
  late _FakePeopleRepository people;
  late MockDmRepository dms;
  late ProviderContainer container;

  setUp(() {
    people = _FakePeopleRepository();
    dms = MockDmRepository();
    container = ProviderContainer(
      overrides: [
        currentOrgIdProvider.overrideWith((ref) => ref.watch(_orgProvider)),
        peopleRepositoryProvider.overrideWithValue(people),
        dmRepositoryProvider.overrideWithValue(dms),
      ],
    );
    addTearDown(container.dispose);
  });

  group('PeopleListNotifier', () {
    test('loads the first page for its search', () async {
      final sub = container.listen(peopleListProvider('ada'), (_, _) {});
      addTearDown(sub.close);

      final list = await container.read(peopleListProvider('ada').future);

      expect(people.requests, [(1, 'ada')]);
      expect(list.members.map((m) => m.id), ['u-1', 'u-2']);
      expect(list.hasMore, isTrue);
      expect(list.total, 3);
    });

    test('load more adds the next page without duplicates', () async {
      final sub = container.listen(peopleListProvider(''), (_, _) {});
      addTearDown(sub.close);
      await container.read(peopleListProvider('').future);

      await container.read(peopleListProvider('').notifier).loadMore();

      final list = container.read(peopleListProvider('')).value!;
      expect(list.members.map((m) => m.id), ['u-1', 'u-2', 'u-3']);
      expect(list.hasMore, isFalse);

      // Nothing more to load.
      await container.read(peopleListProvider('').notifier).loadMore();
      expect(people.requests, [(1, ''), (2, '')]);
    });

    test('a failed load more keeps the members and can retry', () async {
      people.failPage2 = true;
      final sub = container.listen(peopleListProvider(''), (_, _) {});
      addTearDown(sub.close);
      await container.read(peopleListProvider('').future);

      await container.read(peopleListProvider('').notifier).loadMore();

      final list = container.read(peopleListProvider('')).value!;
      expect(list.members, hasLength(2));
      expect(list.loadMoreFailed, isTrue);
      expect(list.hasMore, isTrue);
    });

    test(
      'loadMore completing after workspace switch does not overwrite new workspace members',
      () async {
        final sub = container.listen(peopleListProvider(''), (_, _) {});
        addTearDown(sub.close);
        await container.read(peopleListProvider('').future);

        people.hold('org-1', 2);
        final pending = container.read(peopleListProvider('').notifier).loadMore();

        // Switch workspace to org-2
        container.read(_orgProvider.notifier).select('org-2');
        await container.read(peopleListProvider('').future);

        // Complete the held page 2 from org-1
        people.held['org-1/2']!.complete(
          const Success(
            MembersPage(
              members: [OrgMember(id: 'u-stale', name: 'Stale')],
              currentPage: 2,
              totalPages: 2,
              totalItems: 3,
            ),
          ),
        );
        await pending;

        final list = container.read(peopleListProvider('')).value!;
        expect(list.members.map((m) => m.id), ['u-b1']);
      },
    );

    test(
      'loadMore failing after workspace switch does not overwrite new workspace members',
      () async {
        final sub = container.listen(peopleListProvider(''), (_, _) {});
        addTearDown(sub.close);
        await container.read(peopleListProvider('').future);

        people.hold('org-1', 2);
        final pending = container.read(peopleListProvider('').notifier).loadMore();

        // Switch workspace to org-2
        container.read(_orgProvider.notifier).select('org-2');
        await container.read(peopleListProvider('').future);

        // Complete with failure from org-1
        people.held['org-1/2']!.complete(
          const Failure(ApiFailure(message: 'late offline error')),
        );
        await pending;

        final list = container.read(peopleListProvider('')).value!;
        expect(list.members.map((m) => m.id), ['u-b1']);
        expect(list.loadMoreFailed, isFalse);
      },
    );
  });

  group('PeopleActionsNotifier.openChat', () {
    const ada = OrgMember(id: 'u-1', name: 'Ada', email: 'ada@zedu.test');

    test('opens the DM and shows it in the DMs tab', () async {
      when(
        () => dms.openConversation(orgId: 'org-1', participantId: 'u-1'),
      ).thenAnswer((_) async => (channelId: 'c-1', participantId: 'u-1'));

      final opened = await container
          .read(peopleActionsProvider.notifier)
          .openChat(ada);

      expect(opened, isTrue);
      final dm = container.read(selectedDmProvider)!;
      expect(dm.channelId, 'c-1');
      expect(dm.displayName, 'Ada');
      expect(dm.participantEmail, 'ada@zedu.test');
      expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
      expect(container.read(peopleActionsProvider), isNull);
    });

    test('reports a failure and stays on People', () async {
      when(
        () => dms.openConversation(orgId: 'org-1', participantId: 'u-1'),
      ).thenThrow(const ApiFailure(message: 'offline'));
      container
          .read(homeSidebarProvider.notifier)
          .setType(HomeSidebarType.people);

      final opened = await container
          .read(peopleActionsProvider.notifier)
          .openChat(ada);

      expect(opened, isFalse);
      expect(container.read(selectedDmProvider), isNull);
      expect(container.read(homeSidebarProvider), HomeSidebarType.people);
      expect(container.read(peopleActionsProvider), isNull);
    });
  });
}
