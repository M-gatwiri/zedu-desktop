import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract interface class CreditsRemoteDataSource {
  Future<List<CreditPackageModel>> getPackages();
  Future<CreditUsageModel> getUsage(String orgId);
  Future<CreditUsageReportModel> getUsageReport(String orgId);
  Future<List<CreditTransactionModel>> getTransactions(String orgId);
  Future<CreditCheckoutModel> purchaseCredits({
    String? packageId,
    String? planId,
    required String email,
  });
  Future<void> verifyPayment({required String sessionId});
}

class CreditsRemoteDataSourceImpl implements CreditsRemoteDataSource {
  CreditsRemoteDataSourceImpl({
    required AppConfig config,
    required ApiBaseService apiBaseService,
  }) : _config = config,
       _api = apiBaseService;

  final AppConfig _config;
  final ApiBaseService _api;
  final Map<String, dynamic> _mockUsage = Map.of(_initialMockUsage);

  @override
  Future<List<CreditPackageModel>> getPackages() async {
    if (_config.usesMockData) {
      return _mockPackages.map(CreditPackageModel.fromJson).toList();
    }
    final response = await _api.get<Map<String, dynamic>>(
      path: '/credits/packages',
    );
    final data = response.data['data'];
    final list = data is List
        ? data
        : (data is Map<String, dynamic> ? data['packages'] : null);
    if (list is! List) return [];
    return list
        .cast<Map<String, dynamic>>()
        .map(CreditPackageModel.fromJson)
        .toList();
  }

  @override
  Future<CreditUsageModel> getUsage(String orgId) async {
    if (_config.usesMockData) {
      return CreditUsageModel.fromJson(_mockUsage);
    }
    final response = await _api.get<Map<String, dynamic>>(
      path: '/credits/usage/$orgId',
    );
    final data = response.data['data'];
    if (data is Map<String, dynamic>) return CreditUsageModel.fromJson(data);

    // The live API returns the usage records as a list (each with an
    // `amount`), and the balance lives on the organisation, which is also how
    // the web app reads them.
    final records = data is List
        ? data.whereType<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    final consumed = records.fold<int>(
      0,
      (sum, record) => sum + ((record['amount'] as num?)?.toInt() ?? 0),
    );
    final org = await _api.get<Map<String, dynamic>>(
      path: '/organisations/$orgId',
    );
    final orgData = org.data['data'];
    final balance = orgData is Map<String, dynamic>
        ? (orgData['credit_balance'] as num?)?.toInt() ?? 0
        : 0;
    return CreditUsageModel(
      balance: balance,
      totalPurchased: 0,
      totalConsumed: consumed,
    );
  }

  @override
  Future<CreditUsageReportModel> getUsageReport(String orgId) async {
    if (_config.usesMockData) {
      return CreditUsageReportModel.fromJson(_mockUsageReport);
    }
    final response = await _api.get<Map<String, dynamic>>(
      path: '/credits/usage-report/$orgId',
    );
    final data = response.data['data'];
    return CreditUsageReportModel.fromJson(
      data is Map<String, dynamic> ? data : const {},
    );
  }

  @override
  Future<List<CreditTransactionModel>> getTransactions(String orgId) async {
    if (_config.usesMockData) {
      return _mockTransactions.map(CreditTransactionModel.fromJson).toList();
    }
    final response = await _api.get<Map<String, dynamic>>(
      path: '/credits/transactions/$orgId',
    );
    final data = response.data['data'];
    final list = data is List
        ? data
        : (data is Map ? data['transactions'] : null);
    if (list is! List) return [];
    return list
        .cast<Map<String, dynamic>>()
        .map(CreditTransactionModel.fromJson)
        .toList();
  }

  @override
  Future<CreditCheckoutModel> purchaseCredits({
    String? packageId,
    String? planId,
    required String email,
  }) async {
    final effectivePackageId = packageId ?? planId ?? '';
    if (_config.usesMockData) {
      final sessionId = 'cs_test_mock_${effectivePackageId.hashCode.abs()}';
      return CreditCheckoutModel(
        checkoutSessionId: sessionId,
        checkoutSessionUrl:
            'zedu://credits/payment-success?session_id=$sessionId',
      );
    }
    final response = await _api.post<Map<String, dynamic>>(
      path: '/credits/purchase',
      headers: {'Referer': _config.apiBaseUrl},
      data: {
        'package_id': effectivePackageId,
        'plan_id': effectivePackageId,
        'email': email,
      },
    );
    final data = response.data['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiFailure(
        message: 'Invalid credit checkout response',
        kind: ApiFailureKind.parsing,
      );
    }
    return CreditCheckoutModel.fromJson(data);
  }

  @override
  Future<void> verifyPayment({required String sessionId}) async {
    if (_config.usesMockData) {
      _mockUsage['balance'] = ((_mockUsage['balance'] as int?) ?? 0) + 1000;
      _mockUsage['total_purchased'] =
          ((_mockUsage['total_purchased'] as int?) ?? 0) + 1000;
      return;
    }
    await _api.post<Map<String, dynamic>>(
      path: '/credits/verify-payment',
      data: {'session_id': sessionId},
    );
  }
}

const _initialMockUsage = <String, dynamic>{
  'balance': 10,
  'total_purchased': 10,
  'total_consumed': 0,
};

const _mockUsageReport = <String, dynamic>{
  'balance': 10,
  'purchased': 10,
  'consumed': 0,
  'period_label': 'This month',
};

const _mockTransactions = <Map<String, dynamic>>[
  {
    'id': 'txn-1',
    'amount': 20,
    'credits': 5000,
    'status': 'completed',
    'created_at': '2026-05-01T10:00:00Z',
  },
];

/// Five AI credit packages matching billing screenshots (Free → Enterprise).
const _mockPackages = <Map<String, dynamic>>[
  {
    'id': 'pkg-free',
    'name': 'Free',
    'description': 'Perfect for individuals',
    'price': 0,
    'credits': 0,
    'plan_slug': 'free',
    'benefits': [
      'Create your own AI Co Workers',
      'Unlimited AI Co Workers',
      'AI Credits purchasable',
      '10 Buzz participants',
      '4 Active calls at a time',
    ],
  },
  {
    'id': 'pkg-pro',
    'name': 'Pro',
    'description': 'Perfect for individuals',
    'price': 20,
    'credits': 5000,
    'plan_slug': 'pro',
    'benefits': [
      'All in Free, plus:',
      '10 Buzz participants',
      '4 Active calls at a time',
      'Advanced administrator controls',
    ],
  },
  {
    'id': 'pkg-business',
    'name': 'Business',
    'description': 'Perfect for individuals',
    'price': 50,
    'credits': 15000,
    'plan_slug': 'business',
    'benefits': [
      'All in Pro, plus:',
      'Unlimited call duration',
      '100 Buzz participants',
      '50 Active calls at a time',
      'Call records and transcripts',
    ],
  },
  {
    'id': 'pkg-pro-plus',
    'name': 'Pro Plus',
    'description': 'Built for advanced learning teams',
    'price': 100,
    'credits': 35000,
    'plan_slug': 'pro_plus',
    'benefits': [
      'All in Business, plus:',
      'Priority AI model access',
      'Higher API throughput',
      'Dedicated onboarding support',
      'Advanced usage analytics',
    ],
  },
  {
    'id': 'pkg-enterprise',
    'name': 'Enterprise',
    'description': 'Built for large organizations',
    'price': 250,
    'credits': 100000,
    'plan_slug': 'enterprise',
    'benefits': [
      'All in Pro Plus, plus:',
      'Unlimited Buzz participants',
      'Unlimited active calls',
      'Custom SLA and support',
      'Enterprise security controls',
      'Volume credit discounts',
    ],
  },
];
