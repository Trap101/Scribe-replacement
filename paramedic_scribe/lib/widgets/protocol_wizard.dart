import 'package:flutter/material.dart';
import '../models/protocol_model.dart';

class ProtocolWizard extends StatefulWidget {
  final JrcalcProtocol protocol;

  const ProtocolWizard({super.key, required this.protocol});

  @override
  State<ProtocolWizard> createState() => _ProtocolWizardState();
}

class _ProtocolWizardState extends State<ProtocolWizard> {
  int _currentStep = 0;
  final Map<String, dynamic> _values = {};
  String? _warningMessage;

  ProtocolStep get _step => widget.protocol.steps[_currentStep];
  bool get _isFirst => _currentStep == 0;
  bool get _isLast => _currentStep == widget.protocol.steps.length - 1;

  void _checkWarning(dynamic value) {
    final warning = _step.validationWarning;
    if (warning == null) {
      setState(() => _warningMessage = null);
      return;
    }

    bool triggered = false;
    if (warning.containsKey('trigger_value')) {
      triggered = value == warning['trigger_value'];
    } else if (warning.containsKey('threshold')) {
      final threshold = warning['threshold'] as String;
      if (value is num) {
        if (threshold.startsWith('<')) {
          triggered = value < num.parse(threshold.substring(1));
        } else if (threshold.startsWith('>')) {
          triggered = value > num.parse(threshold.substring(1));
        }
      }
    }

    setState(() =>
        _warningMessage = triggered ? warning['message'] as String? : null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.protocol.name),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Step ${_currentStep + 1}/${widget.protocol.steps.length}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Concept badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _conceptColor(_step.concept).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _step.concept,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _conceptColor(_step.concept),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Instruction
              Text(
                _step.instruction,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 24),
              // Note if present
              if (_step.note != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF0D47A1).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFF0D47A1), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_step.note!,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF0D47A1)))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Warning if triggered
              if (_warningMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.red, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_warningMessage!,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Input widget
              Expanded(child: _buildInput()),
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
                  offset: const Offset(0, -2))
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isFirst
                          ? null
                          : () => setState(() {
                                _currentStep--;
                                _warningMessage = null;
                              }),
                      icon: const Icon(Icons.arrow_back, size: 24),
                      label: const Text('Previous',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isLast
                          ? () => Navigator.pop(context, _values)
                          : () => setState(() {
                                _currentStep++;
                                _warningMessage = null;
                              }),
                      iconAlignment: IconAlignment.end,
                      icon: Icon(_isLast ? Icons.check : Icons.arrow_forward,
                          size: 24),
                      label: Text(_isLast ? 'Complete' : 'Next',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isLast
                            ? const Color(0xFF00838F)
                            : const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    final key = _step.targetField ?? 'step_${_step.stepOrder}';

    switch (_step.actionType) {
      case 'dropdown':
        return _buildDropdown(key);
      case 'toggle':
        return _buildToggle(key);
      case 'input_number':
        return _buildNumberInput(key);
      case 'input_text':
        return _buildTextInput(key);
      case 'multi_select':
        return _buildMultiSelect(key);
      case 'button_action':
        return _buildButtonAction(key);
      default:
        return _buildTextInput(key);
    }
  }

  Widget _buildDropdown(String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            value: _values[key] as String?,
            hint: const Text('Select...'),
            isExpanded: true,
            items: _step.valueOptions
                ?.map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o, style: const TextStyle(fontSize: 15))))
                .toList(),
            onChanged: (v) {
              setState(() => _values[key] = v);
              _checkWarning(v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(String key) {
    final val = _values[key] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        InkWell(
          onTap: () {
            final newVal = !val;
            setState(() => _values[key] = newVal);
            _checkWarning(newVal);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: val
                  ? const Color(0xFF0D47A1).withOpacity(0.1)
                  : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: val
                      ? const Color(0xFF0D47A1)
                      : Colors.black.withOpacity(0.08),
                  width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    val
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: val ? const Color(0xFF0D47A1) : Colors.grey,
                    size: 32),
                const SizedBox(width: 12),
                Text(val ? 'YES' : 'NO',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: val
                            ? const Color(0xFF0D47A1)
                            : Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput(String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Enter value',
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
          onChanged: (v) {
            final num? parsed = num.tryParse(v);
            _values[key] = parsed;
            _checkWarning(parsed);
          },
        ),
      ],
    );
  }

  Widget _buildTextInput(String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          maxLines: 4,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Enter details...',
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
          onChanged: (v) => _values[key] = v,
        ),
      ],
    );
  }

  Widget _buildMultiSelect(String key) {
    final selected = (_values[key] as List<String>?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: (_step.valueOptions ?? []).map((option) {
              final isSelected = selected.contains(option);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      final list = List<String>.from(selected);
                      if (isSelected) {
                        list.remove(option);
                      } else {
                        list.add(option);
                      }
                      _values[key] = list;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0D47A1).withOpacity(0.08)
                          : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0D47A1)
                              : Colors.black.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            isSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: isSelected
                                ? const Color(0xFF0D47A1)
                                : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(option,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400))),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonAction(String key) {
    final done = _values[key] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        if (_step.prefillData != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _step.prefillData!.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text('${e.key}: ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text('${e.value}',
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Center(
          child: FilledButton.icon(
            onPressed: () => setState(() => _values[key] = !done),
            icon: Icon(
                done ? Icons.check_circle : Icons.add_circle_outline,
                size: 24),
            label: Text(
                done ? 'Recorded' : (_step.buttonLabel ?? 'Record'),
                style: const TextStyle(fontSize: 17)),
            style: FilledButton.styleFrom(
              backgroundColor:
                  done ? const Color(0xFF00838F) : const Color(0xFF0D47A1),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Color _conceptColor(String concept) {
    switch (concept.toLowerCase()) {
      case 'assessment':
        return const Color(0xFF0D47A1);
      case 'management':
        return const Color(0xFF00838F);
      case 'immediate risk':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF37474F);
    }
  }
}

/// A drawer-style protocol wizard for use inside showModalBottomSheet.
class ProtocolDrawer extends StatefulWidget {
  final JrcalcProtocol protocol;
  final ScrollController scrollController;

  const ProtocolDrawer({
    super.key,
    required this.protocol,
    required this.scrollController,
  });

  @override
  State<ProtocolDrawer> createState() => _ProtocolDrawerState();
}

class _ProtocolDrawerState extends State<ProtocolDrawer> {
  int _currentStep = 0;
  final Map<String, dynamic> _values = {};
  String? _warningMessage;

  ProtocolStep get _step => widget.protocol.steps[_currentStep];
  bool get _isFirst => _currentStep == 0;
  bool get _isLast => _currentStep == widget.protocol.steps.length - 1;

  void _checkWarning(dynamic value) {
    final warning = _step.validationWarning;
    if (warning == null) {
      setState(() => _warningMessage = null);
      return;
    }

    bool triggered = false;
    if (warning.containsKey('trigger_value')) {
      triggered = value == warning['trigger_value'];
    } else if (warning.containsKey('threshold')) {
      final threshold = warning['threshold'] as String;
      if (value is num) {
        if (threshold.startsWith('<')) {
          triggered = value < num.parse(threshold.substring(1));
        } else if (threshold.startsWith('>')) {
          triggered = value > num.parse(threshold.substring(1));
        }
      }
    }

    setState(() =>
        _warningMessage = triggered ? warning['message'] as String? : null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.medical_information, color: Color(0xFF00838F), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.protocol.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'Step ${_currentStep + 1}/${widget.protocol.steps.length}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Concept badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _conceptColor(_step.concept).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _step.concept,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _conceptColor(_step.concept),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _step.instruction,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 24),
                if (_step.note != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_step.note!, style: const TextStyle(fontSize: 13, color: Color(0xFF0D47A1)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_warningMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.red, size: 24),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_warningMessage!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Input - wrapped in SizedBox to give it a constrained height
                SizedBox(
                  height: 300,
                  child: _buildInput(),
                ),
              ],
            ),
          ),
        ),
        // Bottom navigation
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isFirst
                          ? null
                          : () => setState(() {
                                _currentStep--;
                                _warningMessage = null;
                              }),
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
                      onPressed: _isLast
                          ? () => Navigator.pop(context, _values)
                          : () => setState(() {
                                _currentStep++;
                                _warningMessage = null;
                              }),
                      iconAlignment: IconAlignment.end,
                      icon: Icon(_isLast ? Icons.check : Icons.arrow_forward, size: 24),
                      label: Text(_isLast ? 'Complete' : 'Next', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isLast ? const Color(0xFF00838F) : const Color(0xFF0D47A1),
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
      ],
    );
  }

  Widget _buildInput() {
    final key = _step.targetField ?? 'step_${_step.stepOrder}';
    switch (_step.actionType) {
      case 'dropdown':
        return _buildDropdown(key);
      case 'toggle':
        return _buildToggle(key);
      case 'input_number':
        return _buildNumberInput(key);
      case 'input_text':
        return _buildTextInput(key);
      case 'multi_select':
        return _buildMultiSelect(key);
      case 'button_action':
        return _buildButtonAction(key);
      default:
        return _buildTextInput(key);
    }
  }

  Widget _buildDropdown(String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            value: _values[key] as String?,
            hint: const Text('Select...'),
            isExpanded: true,
            items: _step.valueOptions?.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 15)))).toList(),
            onChanged: (v) {
              setState(() => _values[key] = v);
              _checkWarning(v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(String key) {
    final val = _values[key] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        InkWell(
          onTap: () {
            final newVal = !val;
            setState(() => _values[key] = newVal);
            _checkWarning(newVal);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: val ? const Color(0xFF0D47A1).withOpacity(0.1) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: val ? const Color(0xFF0D47A1) : Colors.black.withOpacity(0.08), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(val ? Icons.check_circle : Icons.radio_button_unchecked, color: val ? const Color(0xFF0D47A1) : Colors.grey, size: 32),
                const SizedBox(width: 12),
                Text(val ? 'YES' : 'NO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: val ? const Color(0xFF0D47A1) : Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput(String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Enter value',
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onChanged: (v) {
            final num? parsed = num.tryParse(v);
            _values[key] = parsed;
            _checkWarning(parsed);
          },
        ),
      ],
    );
  }

  Widget _buildTextInput(String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          maxLines: 4,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Enter details...',
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onChanged: (v) => _values[key] = v,
        ),
      ],
    );
  }

  Widget _buildMultiSelect(String key) {
    final selected = (_values[key] as List<String>?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: (_step.valueOptions ?? []).map((option) {
              final isSelected = selected.contains(option);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      final list = List<String>.from(selected);
                      isSelected ? list.remove(option) : list.add(option);
                      _values[key] = list;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0D47A1).withOpacity(0.08) : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? const Color(0xFF0D47A1) : Colors.black.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? const Color(0xFF0D47A1) : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(child: Text(option, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonAction(String key) {
    final done = _values[key] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_step.uiPrompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        if (_step.prefillData != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _step.prefillData!.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('${e.value}', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Center(
          child: FilledButton.icon(
            onPressed: () => setState(() => _values[key] = !done),
            icon: Icon(done ? Icons.check_circle : Icons.add_circle_outline, size: 24),
            label: Text(done ? 'Recorded' : (_step.buttonLabel ?? 'Record'), style: const TextStyle(fontSize: 17)),
            style: FilledButton.styleFrom(
              backgroundColor: done ? const Color(0xFF00838F) : const Color(0xFF0D47A1),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Color _conceptColor(String concept) {
    switch (concept.toLowerCase()) {
      case 'assessment':
        return const Color(0xFF0D47A1);
      case 'management':
        return const Color(0xFF00838F);
      case 'immediate risk':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF37474F);
    }
  }
}
