import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _Repo implements DmRepository {
  final requestedPages = <int>[];
  bool failPage2 = true;

  @override
  Future<List<DmConversation>> getConversations({
    required String orgId,
    int page = 1,
    bool recentDm = false,
    String? search,
  }) async {
    requestedPages.add(page);
    if (page == 2 && failPage2) {
      failPage2 = false;
      throw Exception('offline');
    }
    return [
      for (var i = 0; i < DmRepository.pageSize; i++)
        DmConversation(
          channelId: 'p$page-$i',
          username: 'u',
          participantId: 'x',
          previewMessage: '',
          unreadCount: 0,
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('retrying a failed "load more" asks for the same page again', () async {
    final repo = _Repo();
    final container = ProviderContainer(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repo),
        currentOrgIdProvider.overrideWithValue('org-a'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(dmListProvider.future);
    final notifier = container.read(dmListProvider.notifier);

    try {
      await notifier.loadMore(); // page 2 fails
    } catch (_) {}
    await notifier.loadMore(); // retry

    // Page 2 must not be skipped.
    expect(repo.requestedPages, [1, 2, 2]);
  });

  test('loading more pages in turn asks for each page once', () async {
    final repo = _Repo()..failPage2 = false;
    final container = ProviderContainer(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repo),
        currentOrgIdProvider.overrideWithValue('org-a'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(dmListProvider.future);
    final notifier = container.read(dmListProvider.notifier);

    await notifier.loadMore();
    await notifier.loadMore();

    expect(repo.requestedPages, [1, 2, 3]);
  });
}
