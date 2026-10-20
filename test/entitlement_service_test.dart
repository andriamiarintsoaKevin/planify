import 'package:flutter_test/flutter_test.dart';
import 'package:planify/data/entitlement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 18, 12);
  late _MemoryEntitlementCache cache;
  late _FakeEntitlementProvider provider;
  late EntitlementService Function() createService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = _MemoryEntitlementCache();
    provider = _FakeEntitlementProvider();
    createService = () => EntitlementService(
      apiKey: 'public-sdk-key',
      appUserId: 'supabase-user-id',
      proEntitlementId: 'injected-pro-entitlement',
      provider: provider,
      cache: cache,
      clock: () => now,
    );
  });

  test('charge et persiste les droits Pro vérifiés avec expiration', () async {
    provider.status = ProEntitlementStatus(
      isActive: true,
      expiresAt: now.add(const Duration(days: 30)),
      willRenew: true,
    );
    final service = createService();

    await service.initialize();

    expect(service.isPro, isTrue);
    expect(service.snapshot?.isCached, isFalse);
    expect(service.snapshot?.willRenew, isTrue);
    expect(provider.configuredApiKey, 'public-sdk-key');
    expect(provider.configuredUserId, 'supabase-user-id');
    expect(cache.values['supabase-user-id']?.isPro, isTrue);
    service.dispose();
  });

  test('conserve le dernier droit actif hors connexion', () async {
    cache.values['supabase-user-id'] = EntitlementSnapshot(
      isPro: true,
      expiresAt: now.add(const Duration(days: 2)),
      willRenew: true,
      lastVerifiedAt: now.subtract(const Duration(hours: 1)),
    );
    provider.failure = const EntitlementProviderException('hors ligne');
    final service = createService();

    await service.initialize();

    expect(service.isPro, isTrue);
    expect(service.snapshot?.isCached, isTrue);
    expect(service.lastRefreshError, 'hors ligne');
    service.dispose();
  });

  test('rétrograde à Gratuit dès expiration connue', () async {
    cache.values['supabase-user-id'] = EntitlementSnapshot(
      isPro: true,
      expiresAt: now.subtract(const Duration(seconds: 1)),
      willRenew: false,
      lastVerifiedAt: now.subtract(const Duration(days: 1)),
    );
    provider.failure = const EntitlementProviderException('hors ligne');
    final service = createService();

    await service.initialize();

    expect(service.isPro, isFalse);
    expect(service.snapshot?.isCached, isTrue);
    service.dispose();
  });

  test('ne donne jamais accès Pro sans date d’expiration', () async {
    provider.status = const ProEntitlementStatus(
      isActive: true,
      expiresAt: null,
      willRenew: true,
    );
    final service = createService();

    await service.initialize();

    expect(service.isPro, isFalse);
    expect(cache.values['supabase-user-id']?.isPro, isFalse);
    service.dispose();
  });

  test('la clé absente conserve le cache sans configurer RevenueCat', () async {
    cache.values['supabase-user-id'] = EntitlementSnapshot(
      isPro: true,
      expiresAt: now.add(const Duration(days: 3)),
      willRenew: true,
      lastVerifiedAt: now,
    );
    final service = EntitlementService(
      apiKey: '',
      appUserId: 'supabase-user-id',
      proEntitlementId: 'injected-pro-entitlement',
      provider: provider,
      cache: cache,
      clock: () => now,
    );

    await service.initialize();

    expect(service.isPro, isTrue);
    expect(provider.configureCount, 0);
    expect(service.lastRefreshError, contains('non configurée'));
    service.dispose();
  });

  test('isole le cache par compte', () async {
    cache.values['autre-utilisateur'] = EntitlementSnapshot(
      isPro: true,
      expiresAt: now.add(const Duration(days: 3)),
      willRenew: true,
      lastVerifiedAt: now,
    );
    final service = EntitlementService(
      apiKey: '',
      appUserId: 'supabase-user-id',
      proEntitlementId: 'injected-pro-entitlement',
      provider: provider,
      cache: cache,
      clock: () => now,
    );

    await service.initialize();

    expect(service.isPro, isFalse);
    service.dispose();
  });

  test('persiste et relit un état vérifié dans SharedPreferences', () async {
    final persistentCache = SharedPreferencesEntitlementCache();
    final snapshot = EntitlementSnapshot(
      isPro: true,
      expiresAt: now.add(const Duration(days: 10)),
      willRenew: false,
      lastVerifiedAt: now,
    );

    await persistentCache.write('supabase-user-id', snapshot);
    final restored = await persistentCache.read('supabase-user-id');

    expect(restored?.isPro, isTrue);
    expect(restored?.expiresAt, snapshot.expiresAt);
    expect(restored?.willRenew, isFalse);
    expect(restored?.isCached, isTrue);
  });
}

class _MemoryEntitlementCache implements EntitlementCache {
  final Map<String, EntitlementSnapshot> values = {};

  @override
  Future<EntitlementSnapshot?> read(String appUserId) async =>
      values[appUserId]?.asCached();

  @override
  Future<void> write(String appUserId, EntitlementSnapshot snapshot) async {
    values[appUserId] = snapshot;
  }
}

class _FakeEntitlementProvider implements EntitlementProvider {
  ProEntitlementStatus status = ProEntitlementStatus(
    isActive: false,
    expiresAt: null,
    willRenew: false,
  );
  EntitlementProviderException? failure;
  String? configuredApiKey;
  String? configuredUserId;
  var configureCount = 0;

  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {
    configureCount += 1;
    configuredApiKey = apiKey;
    configuredUserId = appUserId;
  }

  @override
  Future<ProEntitlementStatus> fetchProEntitlement(String entitlementId) async {
    final error = failure;
    if (error != null) throw error;
    return status;
  }
}
