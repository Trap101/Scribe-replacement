enum FieldType { text, tick, number, dropdown, time, date, signature }

class FormFieldModel {
  final String id;
  final String label;
  final FieldType type;
  dynamic value;
  final List<String>? options; // for dropdown
  final bool required;
  bool isAiFilled;

  FormFieldModel({
    required this.id,
    required this.label,
    required this.type,
    this.value,
    this.options,
    this.required = false,
    this.isAiFilled = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'value': value,
        'options': options,
        'required': required,
        'isAiFilled': isAiFilled,
      };

  factory FormFieldModel.fromJson(Map<String, dynamic> json) =>
      FormFieldModel(
        id: json['id'],
        label: json['label'],
        type: FieldType.values.byName(json['type']),
        value: json['value'],
        options: json['options'] != null ? List<String>.from(json['options']) : null,
        required: json['required'] ?? false,
        isAiFilled: json['isAiFilled'] ?? false,
      );
}
