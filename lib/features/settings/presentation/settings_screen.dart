import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/recorder_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.0 (Build 1)';
  static const String _privacyPolicyUrl =
      'https://your-domain.com/privacy-policy';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorderState = ref.watch(recorderProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                children: [
                  // ── Recording section ──
                  _SectionHeader('Recording'),
                  _SettingsTile(
                    icon: CupertinoIcons.waveform,
                    title: 'Noise Suppression',
                    subtitle: 'Built-in hardware noise reduction',
                    trailing: const Icon(Icons.check_circle,
                        color: Color(0xFF4CAF50), size: 18),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.mic,
                    title: 'Echo Cancellation',
                    subtitle: 'Built-in hardware echo cancellation',
                    trailing: const Icon(Icons.check_circle,
                        color: Color(0xFF4CAF50), size: 18),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.speedometer,
                    title: 'Sample Rate',
                    subtitle: '44,100 Hz (CD quality)',
                    trailing: null,
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.layers,
                    title: 'Bit Depth',
                    subtitle: '16-bit PCM',
                    trailing: null,
                  ),
                  const SizedBox(height: 16),

                  // ── Noise gate section ──
                  _SectionHeader('Noise Gate'),
                  _SettingsTile(
                    icon: CupertinoIcons.dial,
                    title: 'Noise Gate',
                    subtitle: recorderState.isNoiseGateEnabled
                        ? 'Enabled — threshold ${recorderState.noiseGateThreshold.toStringAsFixed(0)} dB'
                        : 'Disabled',
                    trailing: Switch(
                      value: recorderState.isNoiseGateEnabled,
                      activeThumbColor: const Color(0xFFF95B5B),
                      activeTrackColor:
                          const Color(0xFFF95B5B).withValues(alpha: 0.4),
                      onChanged: (val) => ref
                          .read(recorderProvider.notifier)
                          .toggleNoiseGate(val),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── About section ──
                  _SectionHeader('About'),
                  _SettingsTile(
                    icon: CupertinoIcons.info,
                    title: 'Version',
                    subtitle: _appVersion,
                    trailing: null,
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.lock_shield,
                    title: 'Privacy Policy',
                    subtitle: _privacyPolicyUrl,
                    trailing: const Icon(Icons.open_in_new,
                        color: Colors.white38, size: 16),
                    onTap: () {
                      // TODO: launch URL when url_launcher is added
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening privacy policy…'),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.doc_text,
                    title: 'Open Source Licences',
                    subtitle: 'Third-party libraries used by this app',
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.white38),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'EchoRecorder',
                      applicationVersion: _appVersion,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'EchoRecorder $_appVersion\n© ${DateTime.now().year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFF95B5B),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF23252A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
