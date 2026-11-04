import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('CreditsRemoteDataSourceImpl.getUsage', () {
    late MockApiBaseService mockApi;
    late CreditsRemoteDataSourceImpl datasource;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = CreditsRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://api.example.com',
          usesMockData: false,
        ),
        apiBaseService: mockApi,
      );
    });

    void stubGet(String path, Object? data) {
      when(() => mockApi.get<Map<String, dynamic>>(path: path)).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: {'data': data},
          statusCode: 200,
        ),
      );
    }

    test('reads a summary object', () async {
      stubGet('/credits/usage/org-1', {
        'balance': 120,
        'total_purchased': 200,
        'total_consumed': 80,
      });

      final usage = await datasource.getUsage('org-1');

      expect(usage.balance, 120);
      expect(usage.totalPurchased, 200);
      expect(usage.totalConsumed, 80);
    });

    test(
      'sums a list of usage records and takes the balance from the organisation',
      () async {
        stubGet('/credits/usage/org-1', [
          {'amount': 3, 'created_at': '2026-11-04T10:00:00Z'},
          {'amount': 7, 'created_at': '2026-11-04T11:00:00Z'},
        ]);
        stubGet('/organisations/org-1', {'id': 'org-1', 'credit_balance': 990});

        final usage = await datasource.getUsage('org-1');

        expect(usage.totalConsumed, 10);
        expect(usage.balance, 990);
      },
    );

    test('treats an empty usage list as no usage', () async {
      stubGet('/credits/usage/org-1', <dynamic>[]);
      stubGet('/organisations/org-1', {'id': 'org-1', 'credit_balance': 50});

      final usage = await datasource.getUsage('org-1');

      expect(usage.totalConsumed, 0);
      expect(usage.balance, 50);
    });
  });
}
