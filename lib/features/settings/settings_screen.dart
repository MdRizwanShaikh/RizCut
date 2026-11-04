import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
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
      if (mounted && i.version.isNotEmpty) {
        setState(() => _version = i.buildNumber.isEmpty ? i.version : '${i.version} (${i.buildNumber})');
      }
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

  static const _playUrl = 'https://play.google.com/store/apps/details?id=com.rizcut.app';
  static const _contactEmail = 'therizwan027@gmail.com';

  Future<void> _copyEmail() async {
    try {
      await Clipboard.setData(const ClipboardData(text: _contactEmail));
      _toast('Email copied');
    } catch (_) {
      _toast(_contactEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = cloud.user;
    final (statusLabel, statusColor) = !cloud.available
        ? ('Off', RizColors.textDim)
        : user == null
            ? ('Not signed in', const Color(0xFFFFB36B))
            : ('Backed up', const Color(0xFF3DDC97));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _AppHeader(version: _version),
          const SizedBox(height: 22),
          const _Header('Account & backup'),
          _Card(
            children: [
              _SettingsTile(
                icon: Icons.cloud_outlined,
                color: RizColors.cyan,
                title: 'Cloud backup',
                subtitle: !cloud.available
                    ? 'Not available in this build. Drafts stay on this phone.'
                    : user == null
                        ? 'Optional. Keep project edits safe. Videos stay on your phone.'
                        : (user.email ?? user.displayName ?? 'Signed in'),
                trailing: _Pill(statusLabel, statusColor),
              ),
              if (cloud.available && user == null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: SizedBox(
                    width: double.infinity,
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _emailSignIn,
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Use email instead'),
                    ),
                  ),
                ),
              ],
              if (user != null) ...[
                const _Divider(),
                _SettingsTile(
                  icon: Icons.cloud_upload_outlined,
                  color: RizColors.blue,
                  title: 'Back up drafts now',
                  onTap: _busy
                      ? null
                      : () => _run(() async {
                            final n = await cloud.backUp();
                            return 'Backed up $n draft${n == 1 ? '' : 's'}';
                          }),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: Icons.cloud_download_outlined,
                  color: RizColors.violet,
                  title: 'Restore drafts',
                  onTap: _busy
                      ? null
                      : () => _run(() async {
                            final n = await cloud.restore();
                            return n == 0
                                ? 'Drafts are already up to date'
                                : 'Restored $n draft${n == 1 ? '' : 's'}';
                          }),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: Icons.logout,
                  color: RizColors.textDim,
                  title: 'Sign out',
                  onTap: _busy
                      ? null
                      : () => _run(() async {
                            await cloud.signOut();
                            return 'Signed out';
                          }),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  color: const Color(0xFFFF5C7A),
                  title: 'Delete account',
                  subtitle: 'Removes your account and cloud backups',
                  onTap: _busy ? null : _confirmDelete,
                ),
              ],
              if (_busy) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
          const SizedBox(height: 22),
          const _Header('Support'),
          _Card(
            children: [
              _SettingsTile(
                icon: Icons.star_outline,
                color: const Color(0xFFFFD54F),
                title: 'Rate RizCut',
                subtitle: 'A quick rating helps a lot',
                onTap: () => launchUrl(Uri.parse(_playUrl), mode: LaunchMode.externalApplication),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.share_outlined,
                color: RizColors.pink,
                title: 'Share with friends',
                onTap: () => SharePlus.instance.share(ShareParams(
                    text: 'I edit my videos with RizCut — free, no watermark: $_playUrl')),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.mail_outline,
                color: RizColors.cyan,
                title: 'Contact & feedback',
                subtitleWidget: const SelectableText(_contactEmail,
                    style: TextStyle(color: RizColors.textDim, fontSize: 13)),
                trailing: IconButton(
                  tooltip: 'Copy email',
                  onPressed: _copyEmail,
                  icon: const Icon(Icons.copy, size: 18, color: RizColors.textDim),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _Header('About'),
          _Card(
            children: [
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                color: RizColors.violet,
                title: 'Privacy policy',
                trailing: const Icon(Icons.open_in_new, size: 18, color: RizColors.textDim),
                onTap: () => launchUrl(Uri.parse(kPrivacyPolicyUrl),
                    mode: LaunchMode.externalApplication),
              ),
              const _Divider(),
              _SettingsTile(
                icon: Icons.article_outlined,
                color: RizColors.blue,
                title: 'Open-source licenses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'RizCut',
                  applicationVersion: _version,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Center(
            child: Text('Made with ♥ for creators',
                style: TextStyle(color: RizColors.textDim, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Logo, name and version at the top of Settings.
class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.version});
  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            RizColors.magenta.withValues(alpha: 0.22),
            RizColors.blue.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: RizColors.outline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/branding/icon.png', width: 60, height: 60),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RizCut',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const Text('Video editor for creators',
                    style: TextStyle(color: RizColors.textDim, fontSize: 13)),
                const SizedBox(height: 6),
                _Pill(version.isEmpty ? 'Version $kAppVersion' : 'Version $version',
                    RizColors.cyan),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback when the platform can't report the version (web preview).
const kAppVersion = '1.0.0';

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: RizColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
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

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 64, color: RizColors.outline);
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

/// A row with a coloured icon tile, title, optional subtitle and trailing.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          style: const TextStyle(color: RizColors.textDim, fontSize: 13)),
                    ),
                  ?subtitleWidget,
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!]
            else if (onTap != null)
              const Icon(Icons.chevron_right, color: RizColors.textDim),
          ],
        ),
      ),
    );
  }
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
