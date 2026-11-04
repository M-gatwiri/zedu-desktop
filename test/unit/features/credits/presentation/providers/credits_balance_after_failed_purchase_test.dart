import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockCreditsRepository extends Mock implements CreditsRepository {}

class _Workspaces extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-2', name: 'Second', avatar: ''),
  );
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'u1',
      firstName: 'A',
      lastName: 'B',
      email: 'a@b.co',
      phone: '',
      username: 'ab',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: '',
      avatarUrl: '',
      defaultAvatarUrl: '',
      // The balance of the sign-in organisation, org-1.
      creditBalance: 10,
    ),
  );
}

const _package = CreditPackage(
  id: 'pro',
  name: 'Pro',
  description: '',
  price: 20,
  credits: 5000,
  benefits: [],
);

void main() {
  late _MockCreditsRepository repo;

  setUp(() {
    repo = _MockCreditsRepository();
    when(() => repo.getUsage('org-2')).thenAnswer(
      (_) async => const Success(
        CreditUsage(balance: 500, totalPurchased: 500, totalConsumed: 0),
      ),
    );
    when(() => repo.getUsageReport('org-2')).thenAnswer(
      (_) async => const Success(
        CreditUsageReport(
          balance: 500,
          purchased: 500,
          consumed: 0,
          periodLabel: 'This month',
        ),
      ),
    );
    when(
      () => repo.getTransactions('org-2'),
    ).thenAnswer((_) async => const Success<List<CreditTransaction>>([]));
  });

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: [
        creditsRepositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(_Workspaces.new),
        authNotifierProvider.overrideWith(_Auth.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(orgCreditBalanceProvider, (_, _) {});
    return container;
  }

  test(
    'a failed purchase does not change the credit balance shown for the workspace',
    () async {
      when(
        () => repo.getPackages(),
      ).thenAnswer((_) async => const Success<List<CreditPackage>>([_package]));
      when(
        () => repo.purchaseCredits(
          planId: any(named: 'planId'),
          email: any(named: 'email'),
        ),
      ).thenAnswer(
        (_) async =>
            const Failure<CreditCheckoutSession>(ApiFailure(message: 'down')),
      );
      final container = newContainer();

      await container
          .read(creditsNotifierProvider.notifier)
          .load(orgId: 'org-2');
      expect(container.read(orgCreditBalanceProvider), 500);

      await container
          .read(creditsNotifierProvider.notifier)
          .purchasePackage(package: _package, email: 'a@b.co');

      expect(
        container.read(orgCreditBalanceProvider),
        500,
        reason: 'the loaded balance is still correct after a failed checkout',
      );
    },
  );

  test('a failed load still falls back to the signed-in balance', () async {
    when(() => repo.getPackages()).thenAnswer(
      (_) async =>
          const Failure<List<CreditPackage>>(ApiFailure(message: 'down')),
    );
    when(() => repo.getUsage('org-2')).thenAnswer(
      (_) async => const Failure<CreditUsage>(ApiFailure(message: 'down')),
    );
    final container = newContainer();

    await container.read(creditsNotifierProvider.notifier).load(orgId: 'org-2');

    expect(container.read(orgCreditBalanceProvider), 10);
  });
}
