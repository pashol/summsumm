import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../../providers/meeting_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/ai_service.dart';

class ApiConnectionScreen extends ConsumerStatefulWidget {
  const ApiConnectionScreen({super.key});

  @override
  ConsumerState<ApiConnectionScreen> createState() => _ApiConnectionScreenState();
}

class _ApiConnectionScreenState extends ConsumerState<ApiConnectionScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _showKey = false;
  bool _testingConnection = false;
  String? _connectionResult;
  bool _connectionError = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final key = await notifier.getApiKey(settings.provider) ?? '';
    if (mounted) {
      _apiKeyCtrl.text = key;
    }
  }

  Future<void> _saveKey() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.saveApiKey(settings.provider, _apiKeyCtrl.text.trim());
  }

  Future<void> _testConnection() async {
    await _saveKey();
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final apiKey = await notifier.getApiKey(settings.provider) ?? '';

    if (apiKey.isEmpty) {
      setState(() {
        _connectionResult = AppLocalizations.of(context)!.settingsEnterApiKeyFirst;
        _connectionError = true;
      });
      return;
    }

    final model = settings.activeModel;

    if (model.isEmpty) {
      setState(() {
        _connectionResult = AppLocalizations.of(context)!.settingsSelectModelFirst;
        _connectionError = true;
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _connectionResult = null;
    });
    try {
      await ref.read(aiServiceProvider).testConnection(
            apiKey: apiKey,
            model: model,
            provider: settings.provider,
          );
      if (mounted) {
        setState(() {
          _connectionResult = AppLocalizations.of(context)!.settingsConnectionSuccess;
          _connectionError = false;
        });
      }
    } on AiException catch (e) {
      if (mounted) {
        setState(() {
          _connectionResult = e.message;
          _connectionError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionResult = e.toString();
          _connectionError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final isProviderOpenAi = settings.provider == 'openai';
    final providerLabel = isProviderOpenAi ? l10n.settingsOpenAi : l10n.settingsOpenRouter;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsApiKeySection(providerLabel)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _apiKeyCtrl,
            obscureText: !_showKey,
            decoration: InputDecoration(
              labelText: l10n.settingsApiKeyLabel,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _showKey ? Icons.visibility_off : Icons.visibility,),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
            onEditingComplete: _saveKey,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _saveKey,
                  child: Text(l10n.settingsSaveKey),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: _testingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(l10n.settingsTestButton),
                ),
              ),
            ],
          ),
          if (_connectionResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _connectionResult!,
              style: TextStyle(
                color: _connectionError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
