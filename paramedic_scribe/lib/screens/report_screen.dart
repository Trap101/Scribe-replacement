import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../models/report_model.dart';
import '../models/form_field_model.dart';
import '../services/pdf_export_service.dart';
import '../services/claude_service.dart';
import '../services/elevenlabs_service.dart';
import '../services/storage_service.dart';
import '../services/aepr_loader_service.dart';
import '../services/semantic_search_service.dart';
import '../widgets/form_field_widget.dart';
import '../services/protocol_service.dart';
import '../models/protocol_model.dart';
import '../widgets/protocol_wizard.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

enum ReportMode { manual, prompt }

class ReportScreen extends StatefulWidget {
  final String? reportId;
  final ReportMode mode;
  final String? prompt;
  final String? protocolName;
  final bool autofill;

  const ReportScreen({
    super.key,
    this.reportId,
    this.mode = ReportMode.manual,
    this.prompt,
    this.protocolName,
    this.autofill = false,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late ParamedicReport _report;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isProcessingAI = false;
  bool _isAutoFilling = false;
  bool _showAiTextInput = false;
  late TabController _mainTabController;
  final _searchController = TextEditingController();
  final _aiTextController = TextEditingController();
  String _searchQuery = '';
  List<JrcalcProtocol> _protocols = [];

  // Shared between both modes
  List<FormSection> _allSections = [];

  static const baselineFieldIds = <String>[
    'Patient Details.familyName',
    'Patient Details.givenName',
    'Patient Details.dateOfBirth',
    'Patient Details.age',
    'Patient Details.sex',
    'Patient Details.NHSNumber',
    'Chief Complaint.presentingComplaint',
    'Chief Complaint.assessmentTime',
    'Known Allergy.type',
    'Current Medication.name',
    'Chief Complaint.pastMedicalHistory',
    'AVPU Assessment.AVPUScale',
    'Airway Assessment.airwayStatus',
    'Breathing Assessment.respiratoryRate',
    'Pulse Oximetry.SpO2 reading',
    'Circulatory Assessment.pulseRate',
    'Blood Pressure.systolicBP',
    'Blood Pressure.diastolicBP',
    'Glasgow Coma Scale.GCSTotal',
    'Body Temperature.value',
    'Blood Glucose.bloodGlucose',
    'Patient Management.Impressions',
    'Disposition.destinationType',
  ];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _loadReport();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _searchController.dispose();
    _aiTextController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    if (widget.mode == ReportMode.prompt) {
      await _buildSmartReport();
    } else {
      await _loadManualReport();
    }
  }

  Future<void> _loadManualReport() async {
    _allSections = await AeprLoaderService().loadSections();
    try {
      _protocols = await ProtocolService().loadProtocols();
    } catch (_) {}

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
      // Build manual sections: Essential + Baseline Required + all category sections
      final allFieldsMap = <String, FormFieldModel>{};
      for (final section in _allSections) {
        for (final field in section.fields) {
          allFieldsMap[field.id] = field;
        }
      }

      final baselineFields = <FormFieldModel>[];
      for (final fieldId in baselineFieldIds) {
        final field = allFieldsMap[fieldId];
        if (field != null) {
          baselineFields.add(FormFieldModel(
            id: field.id,
            label: field.label,
            type: field.type,
            options: field.options,
          ));
        }
      }

      final manualSections = <FormSection>[];

      // 1. Essential Fields section
      final essentialSection =
          _allSections.where((s) => s.title == 'Essential Fields').firstOrNull;
      if (essentialSection != null) {
        manualSections.add(FormSection(
          id: 'essential_fields',
          title: 'Essential Fields',
          fields: essentialSection.fields
              .map((f) => FormFieldModel(
                    id: f.id,
                    label: f.label,
                    type: f.type,
                    options: f.options,
                  ))
              .toList(),
        ));
      }

      // 2. Baseline Required section
      if (baselineFields.isNotEmpty) {
        manualSections.add(FormSection(
          id: 'required_fields',
          title: 'Baseline Required',
          fields: baselineFields,
        ));
      }

      // 3. All category sections (excluding Essential Fields which is already added)
      for (final section in _allSections) {
        if (section.title == 'Essential Fields') continue;
        if (section.fields.isNotEmpty) {
          manualSections.add(FormSection(
            id: section.id,
            title: section.title,
            fields: section.fields
                .map((f) => FormFieldModel(
                      id: f.id,
                      label: f.label,
                      type: f.type,
                      options: f.options,
                    ))
                .toList(),
          ));
        }
      }

      _report = ParamedicReport(
        reportId: const Uuid().v4(),
        createdAt: DateTime.now(),
        sections: manualSections,
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _buildSmartReport() async {
    try {
      _allSections = await AeprLoaderService().loadSections();
      try {
        _protocols = await ProtocolService().loadProtocols();
      } catch (_) {}

      final allFieldsMap = <String, FormFieldModel>{};
      for (final section in _allSections) {
        for (final field in section.fields) {
          allFieldsMap[field.id] = field;
        }
      }

      final requiredFields = <FormFieldModel>[];
      for (final fieldId in baselineFieldIds) {
        final field = allFieldsMap[fieldId];
        if (field != null) {
          requiredFields.add(FormFieldModel(
            id: field.id,
            label: field.label,
            type: field.type,
            options: field.options,
          ));
        }
      }

      final protocolFields = <FormFieldModel>[];
      JrcalcProtocol? selectedProtocol;
      if (widget.protocolName != null) {
        selectedProtocol = _protocols
            .where((p) => p.name == widget.protocolName)
            .firstOrNull;
      }
      if (selectedProtocol != null) {
        final addedIds = <String>{};
        for (final id in baselineFieldIds) {
          addedIds.add(id);
        }
        for (final step in selectedProtocol.steps) {
          if (step.targetField != null && !addedIds.contains(step.targetField)) {
            final field = allFieldsMap[step.targetField!];
            if (field != null) {
              protocolFields.add(FormFieldModel(
                id: field.id,
                label: field.label,
                type: field.type,
                options: field.options,
              ));
              addedIds.add(field.id);
            }
          }
        }
      }

      final semanticFields = <FormFieldModel>[];
      final existingIds = <String>{
        ...requiredFields.map((f) => f.id),
        ...protocolFields.map((f) => f.id),
      };
      try {
        final searchResults = await SemanticSearchService()
            .searchAttributesWithContext(
          widget.prompt!,
          protocolName: widget.protocolName,
        );
        for (final attrPath in searchResults) {
          if (!existingIds.contains(attrPath)) {
            final field = allFieldsMap[attrPath];
            if (field != null) {
              semanticFields.add(FormFieldModel(
                id: field.id,
                label: field.label,
                type: field.type,
                options: field.options,
              ));
              existingIds.add(attrPath);
            }
          }
        }
      } catch (_) {}

      final smartSections = <FormSection>[];

      final essentialSection =
          _allSections.where((s) => s.title == 'Essential Fields').firstOrNull;
      if (essentialSection != null) {
        smartSections.add(FormSection(
          id: 'essential_fields',
          title: 'Essential Fields',
          fields: essentialSection.fields
              .map((f) => FormFieldModel(
                    id: f.id,
                    label: f.label,
                    type: f.type,
                    options: f.options,
                  ))
              .toList(),
        ));
      }

      if (requiredFields.isNotEmpty) {
        smartSections.add(FormSection(
          id: 'required_fields',
          title: 'Baseline Required',
          fields: requiredFields,
        ));
      }

      if (protocolFields.isNotEmpty) {
        smartSections.add(FormSection(
          id: 'protocol_fields',
          title: 'Protocol: ${widget.protocolName ?? "Selected"} Fields',
          fields: protocolFields,
        ));
      }

      if (semanticFields.isNotEmpty) {
        smartSections.add(FormSection(
          id: 'suggested_fields',
          title: 'Suggested Fields',
          fields: semanticFields,
        ));
      }

      _report = ParamedicReport(
        reportId: const Uuid().v4(),
        createdAt: DateTime.now(),
        sections: smartSections,
      );

      if (mounted) setState(() => _isLoading = false);

      if (widget.autofill) {
        _runAutofill();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error building report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _runAutofill() async {
    setState(() => _isAutoFilling = true);
    try {
      final result =
          await ClaudeService().extractFormData(widget.prompt!, _report.sections);
      if (result != null && result.isNotEmpty && mounted) {
        setState(() {
          for (final section in _report.sections) {
            for (final field in section.fields) {
              if (result.containsKey(field.id)) {
                field.value = result[field.id];
                field.isAiFilled = true;
              }
            }
          }
        });
        _autoSave();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('${result.length} fields auto-filled'),
              ],
            ),
            backgroundColor: const Color(0xFF00838F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Autofill error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoFilling = false);
    }
  }

  Future<void> _autoSave() async {
    await StorageService().saveSession(_report);
  }

  void _onFieldChanged(FormFieldModel field, [BuildContext? ctx]) {
    setState(() {});
    _autoSave();
    if (field.id == AeprLoaderService.incidentFieldId && field.value is String) {
      final match = _protocols.where((p) => p.name == field.value).firstOrNull;
      if (match != null) {
        _injectProtocolSection(match);
      }
    }
  }

  void _injectProtocolSection(JrcalcProtocol protocol) {
    // Remove any existing protocol section
    _report.sections.removeWhere((s) => s.id == 'protocol_fields');

    final allFieldsMap = <String, FormFieldModel>{};
    for (final section in _allSections) {
      for (final field in section.fields) {
        allFieldsMap[field.id] = field;
      }
    }

    final addedIds = <String>{...baselineFieldIds};
    // Also exclude fields already in the report
    for (final section in _report.sections) {
      if (section.id == 'required_fields' || section.id == 'essential_fields') {
        for (final field in section.fields) {
          addedIds.add(field.id);
        }
      }
    }

    final protocolFields = <FormFieldModel>[];
    for (final step in protocol.steps) {
      if (step.targetField != null && !addedIds.contains(step.targetField)) {
        final field = allFieldsMap[step.targetField!];
        if (field != null) {
          protocolFields.add(FormFieldModel(
            id: field.id,
            label: field.label,
            type: field.type,
            options: field.options,
          ));
          addedIds.add(field.id);
        }
      }
    }

    if (protocolFields.isNotEmpty) {
      // Insert after essential (0) + baseline required (1) = index 2
      final insertIndex = _report.sections.length >= 2 ? 2 : _report.sections.length;
      _report.sections.insert(
        insertIndex,
        FormSection(
          id: 'protocol_fields',
          title: 'Protocol: ${protocol.name} Fields',
          fields: protocolFields,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _showProtocolDrawer(JrcalcProtocol protocol, {BuildContext? ctx}) async {
    final dialogContext = ctx ?? context;
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: dialogContext,
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
      return true;
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

  // --- Manual mode search: find existing fields ---
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

  // --- Prompt mode search: find fields to add ---
  List<_SearchableField> get _availableFields {
    if (_searchQuery.isEmpty) return [];
    final queryWords = _searchQuery.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (queryWords.isEmpty) return [];
    final currentIds = <String>{};
    for (final section in _report.sections) {
      for (final field in section.fields) {
        currentIds.add(field.id);
      }
    }
    final results = <_SearchableField>[];
    for (final section in _allSections) {
      for (final field in section.fields) {
        if (currentIds.contains(field.id)) continue;
        final searchText = [
          field.label,
          field.id,
          section.title,
          if (field.options != null) field.options!.join(' '),
        ].join(' ').toLowerCase();
        if (queryWords.every((w) => searchText.contains(w))) {
          results.add(_SearchableField(
            field: field,
            sectionTitle: section.title,
          ));
        }
      }
    }
    return results;
  }

  void _addFieldToReport(FormFieldModel sourceField) {
    var additionalSection = _report.sections
        .where((s) => s.id == 'additional_fields')
        .firstOrNull;
    if (additionalSection == null) {
      additionalSection = FormSection(
        id: 'additional_fields',
        title: 'Additional Fields',
        fields: [],
      );
      _report.sections.add(additionalSection);
    }

    if (additionalSection.fields.any((f) => f.id == sourceField.id)) return;

    setState(() {
      additionalSection!.fields.add(FormFieldModel(
        id: sourceField.id,
        label: sourceField.label,
        type: sourceField.type,
        options: sourceField.options,
      ));
    });
    _searchController.clear();
    setState(() => _searchQuery = '');
    _autoSave();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${sourceField.label}"'),
        backgroundColor: const Color(0xFF00838F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<_FieldSearchResult> get _allEditedFields {
    final results = <_FieldSearchResult>[];
    for (var i = 0; i < _report.sections.length; i++) {
      final section = _report.sections[i];
      for (final field in section.fields) {
        if (field.value != null &&
            field.value.toString().isNotEmpty &&
            field.value != false) {
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

  void _navigateToSection(int sectionIndex, {String? scrollToFieldId}) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, __) => _SectionDetailScreen(
          report: _report,
          sectionIndex: sectionIndex,
          onFieldChanged: _onFieldChanged,
          scrollToFieldId: scrollToFieldId,
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

    final isManual = widget.mode == ReportMode.manual;

    return Scaffold(
      appBar: AppBar(
        title: Text(isManual ? 'PATIENT REPORT' : 'SMART REPORT'),
        actions: [
          if (_isProcessingAI || _isAutoFilling)
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
          if (isManual)
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
          if (isManual) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.auto_awesome_rounded),
                tooltip: 'AI Assist',
                onPressed: _isProcessingAI
                    ? null
                    : () => setState(() => _showAiTextInput = !_showAiTextInput),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.mic_rounded),
                tooltip: 'Voice Input',
                onPressed: _isProcessingAI ? null : _startVoiceInput,
              ),
            ),
          ],
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
                if (isManual && !_essentialFieldsFilled()) {
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
            // Prompt summary chip (prompt mode only)
            if (!isManual && widget.prompt != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF0D47A1).withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 16, color: Color(0xFF0D47A1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.prompt!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF37474F),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Inline AI text input (manual mode, toggled)
            if (isManual && _showAiTextInput)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0D47A1)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Describe Patient Situation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showAiTextInput = false),
                          child: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _aiTextController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Example: 65-year-old male, chest pain for 30 minutes...',
                        hintStyle: TextStyle(
                          color: Colors.black.withOpacity(0.3),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _isProcessingAI || _aiTextController.text.trim().isEmpty
                            ? null
                            : () {
                                final text = _aiTextController.text.trim();
                                _aiTextController.clear();
                                setState(() => _showAiTextInput = false);
                                _processWithClaude(text);
                              },
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Process with AI'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Search bar
            Padding(
              padding: EdgeInsets.fromLTRB(16, isManual ? 16 : 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: isManual ? 'Search fields...' : 'Search to add more fields...',
                  prefixIcon: Icon(
                    isManual ? Icons.search : Icons.add_circle_outline,
                    size: 20,
                  ),
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
            // All / Edited tabs
            Container(
              color: const Color(0xFF0D47A1),
              child: TabBar(
                controller: _mainTabController,
                tabs: [
                  const Tab(text: 'All'),
                  Tab(text: 'Edited (${_allEditedFields.length})'),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _mainTabController,
                children: [
                  // All tab
                  _searchQuery.isNotEmpty
                      ? (isManual ? _buildSearchResults() : _buildAddFieldResults())
                      : _buildMainContent(),
                  // Edited tab
                  _buildEditedFieldsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Manual mode: search results navigate to fields ---
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
              onTap: () => _navigateToSection(r.sectionIndex, scrollToFieldId: r.field.id),
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

  // --- Prompt mode: search results to add fields ---
  Widget _buildAddFieldResults() {
    final results = _availableFields;
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final r = results[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.add_circle,
                  color: Color(0xFF0D47A1), size: 22),
              title: Text(
                r.field.label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                r.sectionTitle,
                style: TextStyle(
                    fontSize: 12, color: Colors.black.withOpacity(0.4)),
              ),
              trailing: const Icon(Icons.add, size: 20),
              onTap: () => _addFieldToReport(r.field),
              dense: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditedFieldsList() {
    final edited = _allEditedFields;
    if (edited.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_off, size: 48, color: Colors.black.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              'No fields edited yet',
              style: TextStyle(fontSize: 15, color: Colors.black.withOpacity(0.4)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: edited.length,
      itemBuilder: (context, index) {
        final r = edited[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  r.sectionTitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D47A1).withOpacity(0.6),
                  ),
                ),
              ),
              FormFieldWidget(
                field: r.field,
                onChanged: () => _onFieldChanged(r.field),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    final isManual = widget.mode == ReportMode.manual;
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

          // Choose icon/color by section type (prompt mode styling)
          IconData sectionIcon = Icons.assignment;
          Color sectionColor = const Color(0xFF0D47A1);
          if (section.id == 'required_fields') {
            sectionIcon = Icons.checklist_rounded;
            sectionColor = const Color(0xFF2E7D32);
          } else if (section.id == 'protocol_fields') {
            sectionIcon = Icons.medical_information;
            sectionColor = const Color(0xFF00838F);
          } else if (section.id == 'suggested_fields') {
            sectionIcon = Icons.lightbulb_outline;
            sectionColor = const Color(0xFFF57F17);
          } else if (section.id == 'additional_fields') {
            sectionIcon = Icons.add_circle_outline;
            sectionColor = const Color(0xFF7B1FA2);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 2,
              shadowColor: sectionColor.withOpacity(0.1),
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
                              color: sectionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(sectionIcon, color: sectionColor, size: 20),
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
                                backgroundColor: sectionColor.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(sectionColor),
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
              if (isManual && !_essentialFieldsFilled()) {
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
              backgroundColor: isManual && !_essentialFieldsFilled()
                  ? Colors.grey.shade400
                  : const Color(0xFF00838F),
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

class _SearchableField {
  final FormFieldModel field;
  final String sectionTitle;

  _SearchableField({required this.field, required this.sectionTitle});
}

class _SectionDetailScreen extends StatefulWidget {
  final ParamedicReport report;
  final int sectionIndex;
  final void Function(FormFieldModel field, [BuildContext? context]) onFieldChanged;
  final String? scrollToFieldId;

  const _SectionDetailScreen({
    required this.report,
    required this.sectionIndex,
    required this.onFieldChanged,
    this.scrollToFieldId,
  });

  @override
  State<_SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<_SectionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _fieldKeys = {};
  String? _highlightedFieldId;
  bool _hideEmpty = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final section = widget.report.sections[widget.sectionIndex];
    for (final field in section.fields) {
      _fieldKeys[field.id] = GlobalKey();
    }
    if (widget.scrollToFieldId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToField(widget.scrollToFieldId!));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToField(String fieldId) {
    final key = _fieldKeys[fieldId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      ).then((_) {
        if (mounted) {
          setState(() => _highlightedFieldId = fieldId);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _highlightedFieldId = null);
          });
        }
      });
    }
  }

  bool _fieldHasValue(FormFieldModel f) {
    if (f.value == null) return false;
    if (f.value is String && (f.value as String).isEmpty) return false;
    if (f.value is bool && f.value == false) return false;
    return true;
  }

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
    final editedFields = section.fields.where(_fieldHasValue).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(section.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_hideEmpty ? 'Show all' : 'Hide empty'),
              selected: _hideEmpty,
              onSelected: (v) => setState(() => _hideEmpty = v),
              selectedColor: Colors.white.withOpacity(0.25),
              backgroundColor: Colors.white.withOpacity(0.1),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              checkmarkColor: Colors.white,
              side: BorderSide.none,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All (${section.fields.length})'),
            Tab(text: 'Edited (${editedFields.length})'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
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
        child: TabBarView(
          controller: _tabController,
          children: [
            // All fields tab
            _SectionForm(
              key: ValueKey('${section.id}_all'),
              section: section,
              onFieldChanged: (field) {
                widget.onFieldChanged(field, context);
                setState(() {});
              },
              fieldKeys: _fieldKeys,
              scrollController: _scrollController,
              highlightedFieldId: _highlightedFieldId,
              hideEmpty: _hideEmpty,
            ),
            // Edited fields tab
            editedFields.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_off, size: 48,
                            color: Colors.black.withOpacity(0.2)),
                        const SizedBox(height: 12),
                        Text(
                          'No fields edited yet',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: editedFields.length,
                    itemBuilder: (context, index) {
                      final field = editedFields[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FormFieldWidget(
                          field: field,
                          onChanged: () {
                            widget.onFieldChanged(field, context);
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ],
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  final Map<String, GlobalKey>? fieldKeys;
  final ScrollController? scrollController;
  final String? highlightedFieldId;
  final bool hideEmpty;

  const _SectionForm({
    super.key,
    required this.section,
    required this.onFieldChanged,
    this.fieldKeys,
    this.scrollController,
    this.highlightedFieldId,
    this.hideEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayFields = hideEmpty
        ? section.fields.where((f) {
            if (f.value == null) return false;
            if (f.value is String && (f.value as String).isEmpty) return false;
            if (f.value is bool && f.value == false) return false;
            return true;
          }).toList()
        : section.fields;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: displayFields.length + 1,
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
                          hideEmpty
                              ? '${displayFields.length}/${section.fields.length} fields'
                              : '${section.fields.length} fields',
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

        final field = displayFields[index - 1];
        final isHighlighted = highlightedFieldId == field.id;
        return Padding(
          key: fieldKeys?[field.id],
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isHighlighted
                  ? Border.all(color: const Color(0xFF00838F), width: 2)
                  : null,
              color: isHighlighted
                  ? const Color(0xFF00838F).withOpacity(0.06)
                  : Colors.transparent,
            ),
            padding: isHighlighted ? const EdgeInsets.all(4) : EdgeInsets.zero,
            child: FormFieldWidget(
              field: field,
              onChanged: () => onFieldChanged(field),
            ),
          ),
        );
      },
    );
  }
}
