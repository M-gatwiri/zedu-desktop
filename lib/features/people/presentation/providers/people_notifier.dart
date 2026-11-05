import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The members loaded so far for one search, and whether more pages exist.
class PeopleListState {
  final List<OrgMember> members;
  final int loadedPage;
  final int totalPages;
  final int totalItems;
  final bool isLoadingMore;

  /// The last Load more failed; the members already loaded stay.
  final bool loadMoreFailed;

  const PeopleListState({
    this.members = const [],
    this.loadedPage = 0,
    this.totalPages = 1,
    this.totalItems = 0,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  bool get hasMore => loadedPage < totalPages;

  /// [totalItems], or the loaded count when the server gave no total.
  int get total => totalItems > members.length ? totalItems : members.length;

  PeopleListState _withPage(MembersPage page) {
    final seen = {for (final m in members) m.id};
    return PeopleListState(
      members: [
        ...members,
        for (final m in page.members)
          if (seen.add(m.id)) m,
      ],
      loadedPage: page.currentPage,
      totalPages: page.totalPages,
      totalItems: page.totalItems,
    );
  }
}

/// The workspace's members matching one search ('' for everyone), loaded a
/// page at a time.
class PeopleListNotifier extends AsyncNotifier<PeopleListState> {
  PeopleListNotifier(this.search);

  final String search;

  @override
  Future<PeopleListState> build() async {
    final orgId = ref.watch(currentOrgIdProvider);
    if (orgId.isEmpty) return const PeopleListState();
    final page = await _fetch(orgId, 1);
    return const PeopleListState()._withPage(page);
  }

  Future<MembersPage> _fetch(String orgId, int page) async {
    final result = await ref
        .read(peopleRepositoryProvider)
        .fetchMembers(orgId: orgId, page: page, search: search);
    return switch (result) {
      Success<MembersPage>(:final value) => value,
      Failure<MembersPage>(:final error) => throw error,
    };
  }

  /// Loads the next page and adds its members.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    state = AsyncData(
      PeopleListState(
        members: current.members,
        loadedPage: current.loadedPage,
        totalPages: current.totalPages,
        totalItems: current.totalItems,
        isLoadingMore: true,
      ),
    );
    try {
      final page = await _fetch(orgId, current.loadedPage + 1);
      if (!ref.mounted || ref.read(currentOrgIdProvider) != orgId) return;
      state = AsyncData(current._withPage(page));
    } catch (_) {
      if (!ref.mounted || ref.read(currentOrgIdProvider) != orgId) return;
      state = AsyncData(
        PeopleListState(
          members: current.members,
          loadedPage: current.loadedPage,
          totalPages: current.totalPages,
          totalItems: current.totalItems,
          loadMoreFailed: true,
        ),
      );
    }
  }
}

/// Opens the direct message with a member, as the web People page does.
class PeopleActionsNotifier extends Notifier<String?> {
  /// The id of the member whose chat is opening, or null.
  @override
  String? build() => null;

  /// Opens (or creates) the DM with [member] and shows it in the DMs tab.
  /// Returns false when it could not be opened.
  Future<bool> openChat(OrgMember member) async {
    if (state != null) return false;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return false;
    state = member.id;
    try {
      final opened = await ref
          .read(dmRepositoryProvider)
          .openConversation(orgId: orgId, participantId: member.id);
      if (!ref.mounted) return false;
      ref
          .read(selectedDmProvider.notifier)
          .select(
            DmConversation(
              channelId: opened.channelId,
              username: member.displayName,
              participantId: opened.participantId,
              participantEmail: member.email.isEmpty ? null : member.email,
              avatarUrl: member.avatarUrl.isEmpty ? null : member.avatarUrl,
              defaultAvatarUrl: member.defaultAvatarUrl.isEmpty
                  ? null
                  : member.defaultAvatarUrl,
              previewMessage: '',
              unreadCount: 0,
            ),
          );
      ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);
      return true;
    } catch (error) {
      AppLogger.e('Failed to open direct message', error: error);
      return false;
    } finally {
      if (ref.mounted) state = null;
    }
  }
}
