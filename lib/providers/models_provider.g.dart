// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiServiceHash() => r'b6be8ed33706119e4469ff82cefaa6dfbfc95f9b';

/// See also [aiService].
@ProviderFor(aiService)
final aiServiceProvider = Provider<AiService>.internal(
  aiService,
  name: r'aiServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$aiServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AiServiceRef = ProviderRef<AiService>;
String _$openRouterModelsHash() => r'd8bcf4e2d154015ca2e4e04b5151d18393fb55cf';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [openRouterModels].
@ProviderFor(openRouterModels)
const openRouterModelsProvider = OpenRouterModelsFamily();

/// See also [openRouterModels].
class OpenRouterModelsFamily extends Family<AsyncValue<List<AIModel>>> {
  /// See also [openRouterModels].
  const OpenRouterModelsFamily();

  /// See also [openRouterModels].
  OpenRouterModelsProvider call(
    String apiKey,
  ) {
    return OpenRouterModelsProvider(
      apiKey,
    );
  }

  @override
  OpenRouterModelsProvider getProviderOverride(
    covariant OpenRouterModelsProvider provider,
  ) {
    return call(
      provider.apiKey,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'openRouterModelsProvider';
}

/// See also [openRouterModels].
class OpenRouterModelsProvider
    extends AutoDisposeFutureProvider<List<AIModel>> {
  /// See also [openRouterModels].
  OpenRouterModelsProvider(
    String apiKey,
  ) : this._internal(
          (ref) => openRouterModels(
            ref as OpenRouterModelsRef,
            apiKey,
          ),
          from: openRouterModelsProvider,
          name: r'openRouterModelsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$openRouterModelsHash,
          dependencies: OpenRouterModelsFamily._dependencies,
          allTransitiveDependencies:
              OpenRouterModelsFamily._allTransitiveDependencies,
          apiKey: apiKey,
        );

  OpenRouterModelsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.apiKey,
  }) : super.internal();

  final String apiKey;

  @override
  Override overrideWith(
    FutureOr<List<AIModel>> Function(OpenRouterModelsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: OpenRouterModelsProvider._internal(
        (ref) => create(ref as OpenRouterModelsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        apiKey: apiKey,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<AIModel>> createElement() {
    return _OpenRouterModelsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OpenRouterModelsProvider && other.apiKey == apiKey;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, apiKey.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OpenRouterModelsRef on AutoDisposeFutureProviderRef<List<AIModel>> {
  /// The parameter `apiKey` of this provider.
  String get apiKey;
}

class _OpenRouterModelsProviderElement
    extends AutoDisposeFutureProviderElement<List<AIModel>>
    with OpenRouterModelsRef {
  _OpenRouterModelsProviderElement(super.provider);

  @override
  String get apiKey => (origin as OpenRouterModelsProvider).apiKey;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
