import 'form_field_model.dart';

class FormSection {
  final String id;
  final String title;
  final List<FormFieldModel> fields;

  FormSection({
    required this.id,
    required this.title,
    required this.fields,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fields': fields.map((f) => f.toJson()).toList(),
      };

  factory FormSection.fromJson(Map<String, dynamic> json) => FormSection(
        id: json['id'],
        title: json['title'],
        fields: (json['fields'] as List).map((f) => FormFieldModel.fromJson(f)).toList(),
      );
}

class ParamedicReport {
  final String reportId;
  final DateTime createdAt;
  final List<FormSection> sections;
  bool isDraft;

  ParamedicReport({
    required this.reportId,
    required this.createdAt,
    required this.sections,
    this.isDraft = true,
  });

  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'createdAt': createdAt.toIso8601String(),
        'isDraft': isDraft,
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory ParamedicReport.fromJson(Map<String, dynamic> json) => ParamedicReport(
        reportId: json['reportId'],
        createdAt: DateTime.parse(json['createdAt']),
        sections: (json['sections'] as List).map((s) => FormSection.fromJson(s)).toList(),
        isDraft: json['isDraft'] ?? true,
      );
}
