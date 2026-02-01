import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../models/report_model.dart';
import '../models/form_field_model.dart';
import '../models/report_template.dart';
import '../services/pdf_export_service.dart';
import '../services/claude_service.dart';
import '../services/elevenlabs_service.dart';
import '../services/connectivity_service.dart';
import '../services/storage_service.dart';
import '../services/aepr_loader_service.dart';
import '../widgets/form_field_widget.dart';
import '../widgets/input_mode_dialog.dart';
import '../services/protocol_service.dart';
import '../models/protocol_model.dart';
import '../widgets/protocol_wizard.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

class ReportScreen extends StatefulWidget {
  final String? reportId;
  const ReportScreen({super.key, this.reportId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late ParamedicReport _report;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isProcessingAI = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<JrcalcProtocol> _protocols = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    ParamedicReport? loaded;

    if (widget.reportId != null) {
      final json = StorageService().getReportJson(widget.reportId!);
      if (json != null) {
        try {
          loaded = ParamedicReport.fromJson(jsonDecode(json) as Map<String, dynamic>);
        } catch (_) {}
      }
    }

    if (loaded == null) {
      final session = StorageService().loadSession();
      if (session != null) {
        loaded = session;
      }
    }

    if (loaded != null) {
      _report = loaded;
    } else {
      final sections = await AeprLoaderService().loadSections();
      _report = ParamedicReport(
        reportId: const Uuid().v4(),
        createdAt: DateTime.now(),
        sections: sections,
      );
    }
    try {
      _protocols = await ProtocolService().loadProtocols();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _autoSave() async {
    await StorageService().saveSession(_report);
  }

  /// Called when any field changes. Checks if it's the incident field and
  /// auto-opens the protocol drawer if the value matches a protocol name.
  void _onFieldChanged(FormFieldModel field) {
    setState(() {});
    _autoSave();
    if (field.id == AeprLoaderService.incidentFieldId && field.value is String) {
      final match = _protocols.where((p) => p.name == field.value).firstOrNull;
      if (match != null) {
        _showProtocolDrawer(match);
      }
    }
  }

  Future<void> _showProtocolDrawer(JrcalcProtocol protocol) async {
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ProtocolDrawer(
            protocol: protocol,
            scrollController: scrollController,
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        for (final section in _report.sections) {
          for (final field in section.fields) {
            if (result.containsKey(field.id)) {
              field.value = result[field.id];
              field.isAiFilled = false;
            }
          }
        }
      });
      _autoSave();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Protocol "${protocol.name}" completed'),
          backgroundColor: const Color(0xFF00838F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final pdfBytes = await PdfExportService().generateReport(_report);
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showInputModeDialog() async {
    final hasConnection = await ConnectivityService().hasConnection();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => InputModeDialog(
        hasConnection: hasConnection,
        onTextInput: (text) => _processWithClaude(text),
        onVoiceInput: () => _startVoiceInput(),
      ),
    );
  }

  Future<void> _processWithClaude(String text) async {
    setState(() => _isProcessingAI = true);
    try {
      final result = await ClaudeService().extractFormData(text, _report.sections);
      if (result == null || result.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('AI couldn\'t extract any fields from the text. Try being more specific.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else if (mounted) {
        _showAutoFillConfirmation(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAI = false);
    }
  }

  void _showAutoFillConfirmation(Map<String, dynamic> extracted) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF0D47A1)),
            SizedBox(width: 12),
            Text('AI Auto-fill Results'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView(
            children: extracted.entries.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Color(0xFF00838F), size: 20),
                title: Text(
                  e.key,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  e.value.toString(),
                  style: const TextStyle(fontSize: 13),
                ),
                dense: true,
              ),
            )).toList(),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              _applyExtractedData(extracted);
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.done_all),
            label: const Text('Apply All'),
          ),
        ],
      ),
    );
  }

  void _applyExtractedData(Map<String, dynamic> data) {
    setState(() {
      for (final section in _report.sections) {
        for (final field in section.fields) {
          if (data.containsKey(field.id)) {
            field.value = data[field.id];
            field.isAiFilled = true;
          }
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('${data.length} fields auto-filled'),
            ],
          ),
          backgroundColor: const Color(0xFF00838F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _autoSave();
    }
  }

  Future<void> _startVoiceInput() async {
    final recorder = AudioRecorder();

    if (!await recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/recording.wav';

    await recorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);

    if (!mounted) return;

    final shouldStop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.red),
            SizedBox(width: 12),
            Text('Recording...'),
          ],
        ),
        content: const Text('Speak clearly about the patient situation. Tap Stop when finished.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop Recording'),
          ),
        ],
      ),
    );

    if (shouldStop != true) return;

    final recordPath = await recorder.stop();
    await recorder.dispose();

    if (recordPath == null || !mounted) return;

    setState(() => _isProcessingAI = true);

    try {
      final audioBytes = await File(recordPath).readAsBytes();
      final transcript = await ElevenLabsService().transcribeAudio(audioBytes);

      if (transcript != null && transcript.isNotEmpty && mounted) {
        await _processWithClaude(transcript);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not transcribe audio. Please try again or type instead.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAI = false);
    }
  }

  int _filledCount(FormSection section) {
    return section.fields.where((f) {
      if (f.value == null) return false;
      if (f.value is String && (f.value as String).isEmpty) return false;
      if (f.value is bool && f.value == false) return false;
      return true;
    }).length;
  }

  bool _essentialFieldsFilled() {
    if (_report.sections.isEmpty || _report.sections.first.title != 'Essential Fields') {
      return true; // No essential section, allow submission
    }
    final essentialSection = _report.sections.first;
    for (final field in essentialSection.fields) {
      if (field.value == null || field.value.toString().trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  List<String> _missingEssentialFields() {
    if (_report.sections.isEmpty || _report.sections.first.title != 'Essential Fields') {
      return [];
    }
    final essentialSection = _report.sections.first;
    final missing = <String>[];
    for (final field in essentialSection.fields) {
      if (field.value == null || field.value.toString().trim().isEmpty) {
        missing.add(field.label);
      }
    }
    return missing;
  }

  /// Returns a flat list of (sectionIndex, field) pairs matching the search query.
  List<_FieldSearchResult> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    final results = <_FieldSearchResult>[];
    for (var i = 0; i < _report.sections.length; i++) {
      final section = _report.sections[i];
      for (final field in section.fields) {
        if (field.label.toLowerCase().contains(query) ||
            (field.value != null && field.value.toString().toLowerCase().contains(query))) {
          results.add(_FieldSearchResult(
            sectionIndex: i,
            sectionTitle: section.title,
            field: field,
          ));
        }
      }
    }
    return results;
  }

  List<MapEntry<int, FormSection>> get _filteredSections {
    return _report.sections.asMap().entries.toList();
  }

  void _navigateToSection(int sectionIndex) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, __) => _SectionDetailScreen(
          report: _report,
          sectionIndex: sectionIndex,
          onFieldChanged: _onFieldChanged,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('PATIENT REPORT'),
        actions: [
          if (_isProcessingAI)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.note_add),
              tooltip: 'New Report',
              onPressed: () async {
                await StorageService().clearSession();
                final sections = await AeprLoaderService().loadSections();
                setState(() {
                  _report = ParamedicReport(
                    reportId: const Uuid().v4(),
                    createdAt: DateTime.now(),
                    sections: sections,
                  );
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New report started')),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Report',
              onPressed: () async {
                await StorageService().saveReport(_report);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report saved')),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              tooltip: 'AI Assist',
              onPressed: _isProcessingAI ? null : _showInputModeDialog,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export PDF',
              onPressed: _isExporting ? null : () {
                if (!_essentialFieldsFilled()) {
                  final missing = _missingEssentialFields();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please fill in: ${missing.join(', ')}'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  return;
                }
                _exportPdf();
              },
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
              const Color(0xFF0D47A1).withOpacity(0.02),
              const Color(0xFFF4F6F8),
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search fields...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.black.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              'No fields matching "$_searchQuery"',
              style: TextStyle(fontSize: 15, color: Colors.black.withOpacity(0.4)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final r = results[index];
        final hasValue = r.field.value != null &&
            r.field.value.toString().isNotEmpty &&
            r.field.value != false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 1,
            shadowColor: const Color(0xFF0D47A1).withOpacity(0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: InkWell(
              onTap: () => _navigateToSection(r.sectionIndex),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 36,
                      decoration: BoxDecoration(
                        color: hasValue
                            ? const Color(0xFF00838F)
                            : const Color(0xFF0D47A1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.field.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          if (hasValue)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                r.field.value.toString(),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF00838F)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              r.sectionTitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: Color(0xFF0D47A1)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    final hasEssentialSection = _report.sections.isNotEmpty &&
        _report.sections.first.title == 'Essential Fields';

    List<FormFieldModel> topFields = [];
    List<FormFieldModel> bottomFields = [];

    if (hasEssentialSection) {
      final essentialSection = _report.sections.first;
      topFields = essentialSection.fields.where((f) {
        final id = f.id.toLowerCase();
        return id.contains('incident') || id.contains('timeleftscene');
      }).toList();
      bottomFields = essentialSection.fields.where((f) {
        final id = f.id.toLowerCase();
        return id.contains('clinician');
      }).toList();
    }

    // Get non-essential sections
    final cardSections = hasEssentialSection
        ? _filteredSections.where((e) => e.key != 0).toList()
        : _filteredSections;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // Top essential fields
        ...topFields.map((field) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FormFieldWidget(
            field: field,
            onChanged: () => _onFieldChanged(field),
          ),
        )),
        if (topFields.isNotEmpty) const SizedBox(height: 8),

        // Section cards
        ...cardSections.map((entry) {
          final sectionIndex = entry.key;
          final section = entry.value;
          final filledCount = _filledCount(section);
          final totalCount = section.fields.length;
          final progress = totalCount > 0 ? filledCount / totalCount : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 2,
              shadowColor: const Color(0xFF0D47A1).withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => _navigateToSection(sectionIndex),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D47A1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.assignment,
                              color: Color(0xFF0D47A1),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              section.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF0D47A1),
                            size: 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '$filledCount/$totalCount filled',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFF0D47A1).withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
                                minHeight: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        // Bottom essential fields
        ...bottomFields.map((field) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FormFieldWidget(
            field: field,
            onChanged: () => _onFieldChanged(field),
          ),
        )),

        // Submit & Export PDF button
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isExporting ? null : () async {
              if (!_essentialFieldsFilled()) {
                final missing = _missingEssentialFields();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please fill in: ${missing.join(', ')}'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 4),
                  ),
                );
                return;
              }
              await StorageService().saveReport(_report);
              _exportPdf();
            },
            icon: _isExporting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Icon(Icons.send, size: 24),
            label: Text(
              _isExporting ? 'Generating...' : 'Submit & Export PDF',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _essentialFieldsFilled() ? const Color(0xFF00838F) : Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FieldSearchResult {
  final int sectionIndex;
  final String sectionTitle;
  final FormFieldModel field;

  _FieldSearchResult({
    required this.sectionIndex,
    required this.sectionTitle,
    required this.field,
  });
}

class _SectionDetailScreen extends StatefulWidget {
  final ParamedicReport report;
  final int sectionIndex;
  final void Function(FormFieldModel field) onFieldChanged;

  const _SectionDetailScreen({
    required this.report,
    required this.sectionIndex,
    required this.onFieldChanged,
  });

  @override
  State<_SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<_SectionDetailScreen> {
  void _navigateToSection(int newIndex) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, __) => _SectionDetailScreen(
          report: widget.report,
          sectionIndex: newIndex,
          onFieldChanged: widget.onFieldChanged,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.report.sections[widget.sectionIndex];
    final isFirst = widget.sectionIndex == 0;
    final isLast = widget.sectionIndex == widget.report.sections.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(section.title),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D47A1).withOpacity(0.02),
              const Color(0xFFF4F6F8),
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: _SectionForm(
          key: ValueKey(section.id),
          section: section,
          onFieldChanged: (field) {
            widget.onFieldChanged(field);
            setState(() {});
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isFirst ? null : () => _navigateToSection(widget.sectionIndex - 1),
                    icon: const Icon(Icons.arrow_back, size: 24),
                    label: const Text('Previous', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLast ? null : () => _navigateToSection(widget.sectionIndex + 1),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 24),
                    label: const Text('Next', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionForm extends StatelessWidget {
  final FormSection section;
  final void Function(FormFieldModel field) onFieldChanged;

  const _SectionForm({super.key, required this.section, required this.onFieldChanged});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: section.fields.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0D47A1).withOpacity(0.08),
                    const Color(0xFF1565C0).withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0D47A1).withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${section.fields.length} fields',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
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

        final field = section.fields[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FormFieldWidget(
            field: field,
            onChanged: () => onFieldChanged(field),
          ),
        );
      },
    );
  }
}
