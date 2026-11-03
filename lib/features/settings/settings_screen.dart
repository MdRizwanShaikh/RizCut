import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/cloud/cloud_service.dart';

/// Public privacy policy page (required by Google Play).
const kPrivacyPolicyUrl = String.fromEnvironment(
  'PRIVACY_POLICY_URL',
  defaultValue: 'https://mdrizwanshaikh.github.io/RizCut/privacy-policy.html',
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final cloud = CloudService.instance;
  bool _busy = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    cloud.addListener(_changed);
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = '${i.version} (${i.buildNumber})');
    }).catchError((_) {});
  }

  @override
  void dispose() {
    cloud.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final msg = await action();
      if (msg != null && mounted) _toast(msg);
    } catch (e) {
      if (mounted) _toast(cloudErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailSignIn() async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _EmailSheet(),
    );
    if (result == null) return;
    await _run(() async {
      await cloud.signInWithEmail(result.$1, result.$2);
      return 'Signed in';
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Delete account?', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'This deletes your RizCut account and all cloud backups. '
                'Drafts and videos on this phone stay.',
                style: TextStyle(color: RizColors.textDim),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Keep account'),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C7A)),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _run(() async {
        await cloud.deleteAccount();
        return 'Account deleted';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = cloud.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Header('Account & backup'),
          _Card(
            children: [
              if (!cloud.available)
                const ListTile(
                  leading: Icon(Icons.cloud_off_outlined, color: RizColors.textDim),
                  title: Text('Cloud backup is off in this build'),
                  subtitle: Text(
                      'Everything works without an account. Drafts are saved on this phone.'),
                )
              else if (user == null) ...[
                const ListTile(
                  leading: Icon(Icons.cloud_outlined, color: RizColors.cyan),
                  title: Text('Back up your drafts'),
                  subtitle: Text(
                      'Optional. Sign in to keep project edits safe and restore them later. Videos stay on your phone.'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: GradientButton(
                    key: const Key('google-sign-in'),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await cloud.signInWithGoogle();
                              return 'Signed in';
                            }),
                    icon: Icons.login,
                    label: 'Continue with Google',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _emailSignIn,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Use email instead'),
                  ),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined, color: RizColors.cyan),
                  title: Text(user.email ?? user.displayName ?? 'Signed in'),
                  subtitle: const Text('Backups contain project edits, not video files.'),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Back up drafts now'),
                  enabled: !_busy,
                  onTap: () => _run(() async {
                    final n = await cloud.backUp();
                    return 'Backed up $n draft${n == 1 ? '' : 's'}';
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Restore drafts'),
                  enabled: !_busy,
                  onTap: () => _run(() async {
                    final n = await cloud.restore();
                    return n == 0 ? 'Drafts are already up to date' : 'Restored $n draft${n == 1 ? '' : 's'}';
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  enabled: !_busy,
                  onTap: () => _run(() async {
                    await cloud.signOut();
                    return 'Signed out';
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFFF5C7A)),
                  title: const Text('Delete account'),
                  enabled: !_busy,
                  onTap: _confirmDelete,
                ),
              ],
              if (_busy) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
          const SizedBox(height: 20),
          const _Header('About'),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version'),
                trailing: Text(_version, style: const TextStyle(color: RizColors.textDim)),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(Uri.parse(kPrivacyPolicyUrl),
                    mode: LaunchMode.externalApplication),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Open-source licenses'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'RizCut',
                  applicationVersion: _version,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: RizColors.textDim, fontSize: 12, letterSpacing: 1.2)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: RizColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: RizColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _EmailSheet extends StatefulWidget {
  const _EmailSheet();

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: RizColors.surfaceHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign in with email', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('New email? An account is created for you.',
              style: TextStyle(color: RizColors.textDim)),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: deco('Email'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: deco('Password (6+ characters)'),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GradientButton(
              onPressed: () {
                final e = _email.text.trim(), p = _pass.text;
                if (e.isEmpty || p.isEmpty) return;
                Navigator.of(context).pop((e, p));
              },
              icon: Icons.login,
              label: 'Continue',
            ),
          ),
        ],
      ),
    );
  }
}
