class JrcalcProtocol {
  final String conditionId;
  final String name;
  final String category;
  final List<String> triggers;
  final List<ProtocolStep> steps;

  JrcalcProtocol({
    required this.conditionId,
    required this.name,
    required this.category,
    required this.triggers,
    required this.steps,
  });

  factory JrcalcProtocol.fromJson(Map<String, dynamic> json) {
    return JrcalcProtocol(
      conditionId: json['condition_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      triggers: (json['triggers'] as List).cast<String>(),
      steps: (json['steps'] as List)
          .map((s) => ProtocolStep.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProtocolStep {
  final int stepOrder;
  final String instruction;
  final String concept;
  final String uiPrompt;
  final String actionType;
  final List<String>? valueOptions;
  final String? targetField;
  final String? note;
  final String? buttonLabel;
  final Map<String, dynamic>? prefillData;
  final Map<String, dynamic>? validationWarning;

  ProtocolStep({
    required this.stepOrder,
    required this.instruction,
    required this.concept,
    required this.uiPrompt,
    required this.actionType,
    this.valueOptions,
    this.targetField,
    this.note,
    this.buttonLabel,
    this.prefillData,
    this.validationWarning,
  });

  factory ProtocolStep.fromJson(Map<String, dynamic> json) {
    return ProtocolStep(
      stepOrder: json['step_order'] as int,
      instruction: json['instruction'] as String,
      concept: json['concept'] as String? ?? '',
      uiPrompt: json['ui_prompt'] as String,
      actionType: json['action_type'] as String,
      valueOptions: json['value_options'] != null
          ? (json['value_options'] as List).cast<String>()
          : null,
      targetField: json['target_field'] as String?,
      note: json['note'] as String?,
      buttonLabel: json['button_label'] as String?,
      prefillData: json['prefill_data'] as Map<String, dynamic>?,
      validationWarning: json['validation_warning'] as Map<String, dynamic>?,
    );
  }
}
