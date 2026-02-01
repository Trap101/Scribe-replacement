import 'package:flutter/material.dart';
import 'dart:convert';
import 'report_screen.dart';
import '../services/claude_service.dart';
import '../services/elevenlabs_service.dart';
import '../services/storage_service.dart';
import '../models/report_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PARAMEDIC SCRIBE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D47A1).withOpacity(0.03),
              const Color(0xFFF4F6F8),
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0D47A1),
                      Color(0xFF1565C0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D47A1).withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'Patient Report Form',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Document emergency care with precision',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D47A1).withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: () async {
                    final session = StorageService().loadSession();
                    if (session != null && context.mounted) {
                      final resume = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Resume Previous Report?'),
                          content: const Text('You have an unsaved report in progress. Would you like to continue where you left off?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Start New'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Resume'),
                            ),
                          ],
                        ),
                      );
                      if (resume == false && context.mounted) {
                        await StorageService().clearSession();
                      }
                    }
                    if (context.mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportScreen()),
                      );
                      setState(() {}); // Refresh saved reports list
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: const Text('New Report'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            ..._buildSavedReports(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSavedReports() {
    final reportIds = StorageService().getAllReportIds();
    if (reportIds.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_open, color: Color(0xFF0D47A1), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Saved Reports',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            Text(
              '${reportIds.length}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
      ...reportIds.map((id) {
        // Try to parse the report for display info
        final json = StorageService().getReportJson(id);
        String title = id;
        String subtitle = '';
        if (json != null) {
          try {
            final data = jsonDecode(json) as Map<String, dynamic>;
            title = 'Report ${id.substring(0, 8)}';
            if (data['timestamp'] != null) {
              final dt = DateTime.parse(data['timestamp'] as String);
              subtitle = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            }
          } catch (_) {}
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReportScreen(reportId: id)),
                );
                setState(() {}); // Refresh list on return
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00838F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description, color: Color(0xFF00838F), size: 24),
              ),
              title: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: subtitle.isNotEmpty
                  ? Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.5)))
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 22),
                tooltip: 'Delete report',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Report?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await StorageService().deleteReport(id);
                    setState(() {});
                  }
                },
              ),
            ),
          ),
        );
      }),
    ];
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _claudeKeyController = TextEditingController();
  final _elevenLabsKeyController = TextEditingController();
  bool _keysVisible = false;

  @override
  void dispose() {
    _claudeKeyController.dispose();
    _elevenLabsKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D47A1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.vpn_key_rounded,
                          color: Color(0xFF0D47A1),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'API Configuration',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Secure local storage',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(_keysVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _keysVisible = !_keysVisible),
                        tooltip: _keysVisible ? 'Hide keys' : 'Show keys',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _claudeKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Claude API Key',
                      prefixIcon: Icon(Icons.smart_toy_outlined, size: 20),
                      hintText: 'sk-ant-...',
                    ),
                    obscureText: !_keysVisible,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _elevenLabsKeyController,
                    decoration: const InputDecoration(
                      labelText: 'ElevenLabs API Key',
                      prefixIcon: Icon(Icons.mic_outlined, size: 20),
                      hintText: 'Enter your ElevenLabs key',
                    ),
                    obscureText: !_keysVisible,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await ClaudeService().setApiKey(_claudeKeyController.text);
                        await ElevenLabsService().setApiKey(_elevenLabsKeyController.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Text('API keys saved securely'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF00838F),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                        }
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Configuration'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00838F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF00838F),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'About',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(label: 'Version', value: '1.0.0'),
                  _InfoRow(label: 'Build', value: 'Release'),
                  _InfoRow(label: 'Platform', value: 'Android'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
