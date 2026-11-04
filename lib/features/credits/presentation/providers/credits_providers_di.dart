import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final creditsRemoteDataSourceProvider = Provider<CreditsRemoteDataSource>(
  (ref) => CreditsRemoteDataSourceImpl(
    config: locator<AppConfig>(),
    apiBaseService: locator<ApiBaseService>(),
  ),
);

final creditsRepositoryProvider = Provider<CreditsRepository>(
  (ref) =>
      CreditsRepositoryImpl(remote: ref.watch(creditsRemoteDataSourceProvider)),
);

final creditsNotifierProvider = NotifierProvider<CreditsNotifier, CreditsState>(
  CreditsNotifier.new,
);

final orgCreditBalanceProvider = Provider<int>((ref) {
  final creditsState = ref.watch(creditsNotifierProvider);
  // An error with the packages already loaded is a failed purchase or
  // payment check, not a failed load, so the balance loaded earlier is still
  // the right one to show.
  final usageIsLoaded =
      creditsState.status == CreditsStatus.ready ||
      creditsState.status == CreditsStatus.purchasing ||
      creditsState.status == CreditsStatus.verifying ||
      (creditsState.status == CreditsStatus.error &&
          creditsState.packages.isNotEmpty);
  if (usageIsLoaded) {
    return creditsState.usage.balance;
  }
  return ref.watch(authNotifierProvider).user?.creditBalance ?? 0;
});
