import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/glass_card.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.summarize,
                      size: 32,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_packageInfo != null)
                    Text(
                      '${l10n.aboutVersion} ${_packageInfo!.version}  ${_packageInfo!.buildNumber.isNotEmpty ? '(${_packageInfo!.buildNumber})' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.code,
                      size: 18,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  title: Text(l10n.aboutGitHub),
                  subtitle: Text(l10n.aboutGitHubSubtitle),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => _launchUrl('https://github.com/pashol/summsumm'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: 18,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  title: Text(l10n.aboutDonate),
                  subtitle: Text(l10n.aboutDonateSubtitle),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => _launchUrl('https://ko-fi.com/gggentii'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      size: 18,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  title: Text(l10n.aboutSponsor),
                  subtitle: Text(l10n.aboutSponsorSubtitle),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => _launchUrl('https://github.com/sponsors/pashol'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
