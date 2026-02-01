import 'package:flutter/material.dart';
import '../services/protocol_service.dart';
import '../models/protocol_model.dart';
import 'report_screen.dart';
import '../services/semantic_search_service.dart';

class PromptInputScreen extends StatefulWidget {
  const PromptInputScreen({super.key});

  @override
  State<PromptInputScreen> createState() => _PromptInputScreenState();
}

class _PromptInputScreenState extends State<PromptInputScreen> {
  final _promptController = TextEditingController();
  final _pathwayController = TextEditingController();
  List<JrcalcProtocol> _protocols = [];
  String? _selectedProtocol;
  bool _autofill = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProtocols();
    _promptController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _promptController.dispose();
    _pathwayController.dispose();
    super.dispose();
  }

  Future<void> _loadProtocols() async {
    try {
      _protocols = await ProtocolService().loadProtocols();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _submit() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() => _isSubmitting = true);

    String? protocolName = _selectedProtocol;

    // If no protocol selected, try to infer one from the prompt
    if (protocolName == null) {
      try {
        protocolName = await SemanticSearchService().inferProtocolFromPrompt(prompt);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          mode: ReportMode.prompt,
          prompt: prompt,
          protocolName: protocolName,
          autofill: _autofill,
        ),
      ),
    );
  }

  List<String> _filterProtocols(String query) {
    if (query.isEmpty) return _protocols.map((p) => p.name).toList();
    final lower = query.toLowerCase();
    return _protocols
        .where((p) =>
            p.name.toLowerCase().contains(lower) ||
            p.category.toLowerCase().contains(lower) ||
            p.triggers.any((t) => t.toLowerCase().contains(lower)))
        .map((p) => p.name)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROMPT MODE'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
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
                  // Header
                  Container(
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Describe the Situation',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'A smart report will be generated based on your description',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Prompt text box
                  const Text(
                    'Patient Situation *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _promptController,
                      maxLines: 8,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                      decoration: InputDecoration(
                        hintText:
                            'Example: 65-year-old male, chest pain for 30 minutes, '
                            'history of diabetes and hypertension, BP 150/95, '
                            'pulse 88, SpO2 96% on air...',
                        hintStyle: TextStyle(
                          color: Colors.black.withOpacity(0.3),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // JRCalc pathway - searchable
                  const Text(
                    'JRCalc Pathway (optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Leave empty to auto-detect from your description',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            return _filterProtocols(textEditingValue.text);
                          },
                          onSelected: (selection) {
                            setState(() => _selectedProtocol = selection);
                          },
                          optionsMaxHeight: 200,
                          optionsViewOpenDirection: OptionsViewOpenDirection.down,
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: 200,
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        dense: true,
                                        title: Text(option,
                                            style: const TextStyle(fontSize: 13)),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          fieldViewBuilder:
                              (context, controller, focusNode, onFieldSubmitted) {
                            // Sync our state with this controller
                            if (_selectedProtocol != null &&
                                controller.text != _selectedProtocol) {
                              controller.text = _selectedProtocol!;
                            }
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search pathways...',
                                hintStyle: TextStyle(
                                  color: Colors.black.withOpacity(0.3),
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                prefixIcon: const Icon(
                                    Icons.medical_information_outlined,
                                    size: 20,
                                    color: Color(0xFF0D47A1)),
                                suffixIcon: controller.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          controller.clear();
                                          setState(
                                              () => _selectedProtocol = null);
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (v) {
                                if (v.isEmpty) {
                                  setState(() => _selectedProtocol = null);
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Autofill checkbox
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                    ),
                    child: CheckboxListTile(
                      value: _autofill,
                      onChanged: (v) =>
                          setState(() => _autofill = v ?? false),
                      title: const Text(
                        'AI Autofill',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      subtitle: Text(
                        'Use AI to extract values from your description and pre-fill fields',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                      secondary: const Icon(Icons.auto_fix_high,
                          color: Color(0xFF0D47A1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _promptController.text.trim().isEmpty || _isSubmitting
                          ? null
                          : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 22),
                      label: Text(
                        _isSubmitting ? 'Analyzing...' : 'Generate Report',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
