import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.isPro,
    required this.expiresAt,
    required this.willRenew,
    required this.lastVerifiedAt,
    this.isCached = false,
  });

  final bool isPro;
  final DateTime? expiresAt;
  final bool willRenew;
  final DateTime lastVerifiedAt;
  final bool isCached;

  bool hasProAccessAt(DateTime now) =>
      isPro && expiresAt != null && expiresAt!.isAfter(now);

  EntitlementSnapshot asCached() => EntitlementSnapshot(
    isPro: isPro,
    expiresAt: expiresAt,
    willRenew: willRenew,
    lastVerifiedAt: lastVerifiedAt,
    isCached: true,
  );

  Map<String, Object?> toJson() => {
    'isPro': isPro,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'willRenew': willRenew,
    'lastVerifiedAt': lastVerifiedAt.toUtc().toIso8601String(),
  };

  factory EntitlementSnapshot.fromJson(Map<String, dynamic> json) {
    final isPro = json['isPro'];
    final expiresAt = json['expiresAt'];
    final willRenew = json['willRenew'];
    final lastVerifiedAt = json['lastVerifiedAt'];
    if (isPro is! bool ||
        (expiresAt != null && expiresAt is! String) ||
        willRenew is! bool ||
        lastVerifiedAt is! String) {
      throw const FormatException('État local des droits invalide.');
    }
    final parsedExpiration = expiresAt is String
        ? DateTime.tryParse(expiresAt)
        : null;
    final parsedVerifiedAt = DateTime.tryParse(lastVerifiedAt);
    if ((expiresAt != null && parsedExpiration == null) ||
        parsedVerifiedAt == null) {
      throw const FormatException('Dates locales des droits invalides.');
    }
    return EntitlementSnapshot(
      isPro: isPro,
      expiresAt: parsedExpiration,
      willRenew: willRenew,
      lastVerifiedAt: parsedVerifiedAt,
      isCached: true,
    );
  }
}

class ProEntitlementStatus {
  const ProEntitlementStatus({
    required this.isActive,
    required this.expiresAt,
    required this.willRenew,
  });

  final bool isActive;
  final DateTime? expiresAt;
  final bool willRenew;
}

abstract interface class EntitlementProvider {
  Future<void> configure({required String apiKey, required String appUserId});

  Future<ProEntitlementStatus> fetchProEntitlement(String entitlementId);
}

abstract interface class EntitlementCache {
  Future<EntitlementSnapshot?> read(String appUserId);

  Future<void> write(String appUserId, EntitlementSnapshot snapshot);
}

class SharedPreferencesEntitlementCache implements EntitlementCache {
  static const _keyPrefix = 'planify.entitlement.v1.';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<EntitlementSnapshot?> read(String appUserId) async {
    final json = (await _preferences).getString('$_keyPrefix$appUserId');
    if (json == null) return null;
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('État local des droits invalide.');
    }
    return EntitlementSnapshot.fromJson(decoded);
  }

  @override
  Future<void> write(String appUserId, EntitlementSnapshot snapshot) async {
    final saved = await (await _preferences).setString(
      '$_keyPrefix$appUserId',
      jsonEncode(snapshot.toJson()),
    );
    if (!saved) {
      throw StateError('Impossible d’enregistrer localement les droits.');
    }
  }
}

class EntitlementService extends ChangeNotifier {
  EntitlementService({
    required this.apiKey,
    required this.appUserId,
    required this.proEntitlementId,
    EntitlementProvider? provider,
    EntitlementCache? cache,
    DateTime Function()? clock,
  }) : _provider = provider ?? RevenueCatEntitlementProvider(),
       _cache = cache ?? SharedPreferencesEntitlementCache(),
       _clock = clock ?? DateTime.now;

  final String apiKey;
  final String appUserId;
  final String proEntitlementId;
  final EntitlementProvider _provider;
  final EntitlementCache _cache;
  final DateTime Function() _clock;

  EntitlementSnapshot? _snapshot;
  String? _lastRefreshError;
  bool _initialized = false;
  bool _configured = false;

  EntitlementSnapshot? get snapshot => _snapshot;
  String? get lastRefreshError => _lastRefreshError;
  bool get isPro => _snapshot?.hasProAccessAt(_clock()) ?? false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (appUserId.isEmpty) {
      throw ArgumentError.value(
        appUserId,
        'appUserId',
        'ne peut pas être vide',
      );
    }
    if (proEntitlementId.isEmpty) {
      throw ArgumentError.value(
        proEntitlementId,
        'proEntitlementId',
        'ne peut pas être vide',
      );
    }

    _snapshot = await _cache.read(appUserId);
    _initialized = true;
    notifyListeners();

    if (apiKey.isEmpty) {
      _lastRefreshError =
          'Clé publique RevenueCat non configurée; droits locaux conservés.';
      notifyListeners();
      return;
    }
    try {
      await _provider.configure(apiKey: apiKey, appUserId: appUserId);
      _configured = true;
      await refresh();
    } on EntitlementProviderException catch (error) {
      _lastRefreshError = error.message;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (!_configured) {
      throw StateError('EntitlementService.initialize() requis.');
    }
    try {
      final status = await _provider.fetchProEntitlement(proEntitlementId);
      final now = _clock().toUtc();
      final expiresAt = status.expiresAt?.toUtc();
      final snapshot = EntitlementSnapshot(
        isPro: status.isActive && expiresAt != null && expiresAt.isAfter(now),
        expiresAt: expiresAt,
        willRenew: status.willRenew,
        lastVerifiedAt: now,
      );
      await _cache.write(appUserId, snapshot);
      _snapshot = snapshot;
      _lastRefreshError = null;
      notifyListeners();
    } on EntitlementProviderException catch (error) {
      _lastRefreshError = error.message;
      notifyListeners();
    }
  }
}

class EntitlementProviderException implements Exception {
  const EntitlementProviderException(this.message);

  final String message;
}

class RevenueCatEntitlementProvider implements EntitlementProvider {
  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {
    try {
      if (await Purchases.isConfigured) {
        if (await Purchases.appUserID != appUserId) {
          await Purchases.logIn(appUserId);
        }
        return;
      }
      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = appUserId
        ..entitlementVerificationMode =
            EntitlementVerificationMode.informational;
      await Purchases.configure(configuration);
    } on PlatformException {
      throw const EntitlementProviderException(
        'Impossible d’initialiser RevenueCat. Vérifiez le réseau et la configuration.',
      );
    }
  }

  @override
  Future<ProEntitlementStatus> fetchProEntitlement(String entitlementId) async {
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlement = info.entitlements.all[entitlementId];
      return ProEntitlementStatus(
        isActive: entitlement?.isActive ?? false,
        expiresAt: entitlement?.expirationDate == null
            ? null
            : DateTime.tryParse(entitlement!.expirationDate!),
        willRenew: entitlement?.willRenew ?? false,
      );
    } on PlatformException {
      throw const EntitlementProviderException(
        'Impossible d’actualiser les droits RevenueCat; dernier état conservé.',
      );
    } on FormatException {
      throw const EntitlementProviderException(
        'Réponse RevenueCat invalide; dernier état conservé.',
      );
    }
  }
}
