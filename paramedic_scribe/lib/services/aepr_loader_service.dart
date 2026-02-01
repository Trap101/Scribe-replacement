import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/form_field_model.dart';
import '../models/report_model.dart';
import 'protocol_service.dart';

class AeprLoaderService {
  static const String _cacheBox = 'aepr_cache';
  static const String _hashKey = 'content_hash';
  static const String _sectionsKey = 'cached_sections';

  static final List<String> _sectionOrder = [
    'Essential Fields',
    'Primary Concern',
    'Patient & Scene',
    'Observations',
    'Concerns & Findings',
    'Interventions',
    'The Story',
    'Outcome & Handoff',
  ];

  static const String essentialSectionId = 'essential_fields';

  Future<void> init() async {
    if (!Hive.isBoxOpen(_cacheBox)) {
      await Hive.openBox<String>(_cacheBox);
    }
  }

  Future<List<FormSection>> loadSections() async {
    await init();

    String mergedJson;
    String macroJson;
    try {
      mergedJson = await rootBundle.loadString('assets/Merged_Clinical_Attributes.json');
    } catch (e) {
      throw Exception(
        'Failed to load Merged_Clinical_Attributes.json. '
        'Ensure the file exists in the assets/ folder and is declared in pubspec.yaml. '
        'If running on web, try: flutter clean && flutter pub get && flutter run. '
        'Original error: $e',
      );
    }
    try {
      macroJson = await rootBundle.loadString('assets/Macro_Category_Mapping.json');
    } catch (e) {
      throw Exception(
        'Failed to load Macro_Category_Mapping.json. '
        'Ensure the file exists in the assets/ folder and is declared in pubspec.yaml. '
        'If running on web, try: flutter clean && flutter pub get && flutter run. '
        'Original error: $e',
      );
    }

    final combinedContent = mergedJson + macroJson;
    final currentHash = sha256.convert(utf8.encode(combinedContent)).toString();

    final cacheBox = Hive.box<String>(_cacheBox);
    final cachedHash = cacheBox.get(_hashKey);
    final cachedSections = cacheBox.get(_sectionsKey);

    if (cachedHash == currentHash && cachedSections != null) {
      final List<dynamic> decoded = jsonDecode(cachedSections);
      final sections = decoded
          .map((s) => FormSection.fromJson(s as Map<String, dynamic>))
          .toList();
      await _injectProtocolOptions(sections);
      return sections;
    }

    final sections = _buildSections(mergedJson, macroJson);
    await _injectProtocolOptions(sections);

    await cacheBox.put(_hashKey, currentHash);
    await cacheBox.put(
      _sectionsKey,
      jsonEncode(sections.map((s) => s.toJson()).toList()),
    );

    return sections;
  }

  /// Constant ID used for the incident/condition dropdown field.
  static const String incidentFieldId = 'condition_incident';

  Future<void> _injectProtocolOptions(List<FormSection> sections) async {
    try {
      final protocols = await ProtocolService().loadProtocols();
      final protocolNames = protocols.map((p) => p.name).toList();
      final protocolOptionsWithOther = [...protocolNames, 'Other'];

      // Find the Primary Concern section
      final incidentSection = sections.where(
        (s) => s.title == 'Primary Concern',
      ).firstOrNull;
      if (incidentSection == null) return;

      // Remove all existing incident/condition/chief complaint dropdown fields
      incidentSection.fields.removeWhere((f) {
        final label = f.label.toLowerCase();
        return (label.contains('incident') || label.contains('chief complaint') || label.contains('condition')) &&
            f.type == FieldType.dropdown;
      });

      // Insert a single Primary Concern dropdown at the start
      incidentSection.fields.insert(
        0,
        FormFieldModel(
          id: incidentFieldId,
          label: 'Primary Concern',
          type: FieldType.dropdown,
          options: protocolOptionsWithOther,
        ),
      );

      // Make Patient Management.Impressions a multi-select with conditions
      for (final section in sections) {
        for (var i = 0; i < section.fields.length; i++) {
          if (section.fields[i].id == 'Patient Management.Impressions') {
            section.fields[i] = FormFieldModel(
              id: 'Patient Management.Impressions',
              label: section.fields[i].label,
              type: FieldType.dropdown,
              options: protocolOptionsWithOther,
              multiSelect: true,
            );
            break;
          }
        }
      }

      // Ensure Disposition.destinationType is multi-select
      for (final section in sections) {
        for (var i = 0; i < section.fields.length; i++) {
          if (section.fields[i].id == 'Disposition.destinationType') {
            if (!section.fields[i].multiSelect) {
              section.fields[i] = FormFieldModel(
                id: section.fields[i].id,
                label: section.fields[i].label,
                type: section.fields[i].type,
                options: section.fields[i].options,
                multiSelect: true,
              );
            }
            break;
          }
        }
      }
    } catch (_) {
      // Protocol loading failed - non-fatal, just skip injection
    }
  }

  List<FormSection> _buildSections(String mergedJson, String macroJson) {
    final mergedData = jsonDecode(mergedJson) as Map<String, dynamic>;
    final macroData = jsonDecode(macroJson) as Map<String, dynamic>;

    // Extract attributes by category from merged file
    final attributesData = mergedData['attributes'] as Map<String, dynamic>;

    // Extract macro categories
    final macroCategories = macroData['macro_categories'] as Map<String, dynamic>;

    // Build excluded categories set
    final excludedCategories = <String>{};
    if (macroData['excluded_categories_metadata'] != null) {
      final excludedMeta = macroData['excluded_categories_metadata'] as Map<String, dynamic>;
      final categoriesList = excludedMeta['categories'] as List;
      for (final cat in categoriesList) {
        final categoryName = (cat as Map<String, dynamic>)['category'] as String;
        excludedCategories.add(categoryName);
      }
    }

    final List<FormSection> sections = [];

    // Iterate macro categories in the order defined in _sectionOrder
    for (final sectionTitle in _sectionOrder) {
      // Find the macro category entry with matching display_name
      String? macroKey;
      Map<String, dynamic>? macroCategory;

      for (final entry in macroCategories.entries) {
        final categoryData = entry.value as Map<String, dynamic>;
        if (categoryData['display_name'] == sectionTitle) {
          macroKey = entry.key;
          macroCategory = categoryData;
          break;
        }
      }

      if (macroCategory == null) continue;

      final attributePaths = (macroCategory['attributes'] as List).cast<String>();
      final List<FormFieldModel> fields = [];

      for (final attributePath in attributePaths) {
        // Parse path: "Category.attributeName"
        final parts = attributePath.split('.');
        if (parts.length != 2) continue;

        final categoryName = parts[0];
        final attributeName = parts[1];

        // Skip excluded categories
        if (excludedCategories.contains(categoryName)) continue;

        // Look up in merged attributes
        final categoryData = attributesData[categoryName] as Map<String, dynamic>?;
        if (categoryData == null) continue;

        // Check medic_visible flag if present
        if (categoryData['medic_visible'] == false) continue;

        final attributeData = categoryData[attributeName] as Map<String, dynamic>?;
        if (attributeData == null) continue;

        // Create field from attribute data
        final fieldType = _mapType(attributeData['type'] as String? ?? 'Alphanumeric');

        List<String>? options;
        if (attributeData['values'] != null) {
          final rawValues = (attributeData['values'] as List).cast<String>();
          // Skip if only contains "INSERT LOCAL LIST HERE"
          if (rawValues.length == 1 && rawValues[0] == 'INSERT LOCAL LIST HERE') {
            // Use text field instead of dropdown
            options = null;
          } else if (!rawValues.contains('INSERT LOCAL LIST HERE')) {
            options = rawValues;
          }
        }

        // Determine actual field type based on options
        FieldType actualType = fieldType;
        if (fieldType == FieldType.dropdown && (options == null || options.isEmpty)) {
          actualType = FieldType.text;
        }

        // Special case: signature fields
        if (attributeName.toLowerCase().contains('signature')) {
          actualType = FieldType.signature;
        }

        // Check if this field should be multiSelect
        final isMultiSelect = attributePath == 'Disposition.destinationType';

        fields.add(
          FormFieldModel(
            id: attributePath, // Use full path as field ID
            label: attributeData['description'] as String? ?? attributeName,
            type: actualType,
            options: (actualType == FieldType.dropdown && options != null && options.isNotEmpty)
                ? options
                : null,
            multiSelect: isMultiSelect,
          ),
        );
      }

      if (fields.isNotEmpty) {
        sections.add(
          FormSection(
            id: sectionTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
            title: sectionTitle,
            fields: fields,
          ),
        );
      }
    }

    return sections;
  }

  FieldType _mapType(String aeprType) {
    switch (aeprType) {
      case 'Local List':
        return FieldType.dropdown;
      case 'Multi Select':
        return FieldType.dropdown;
      case 'Numeric':
        return FieldType.number;
      case 'Date':
        return FieldType.date;
      case 'Time':
        return FieldType.time;
      case 'Boolean':
        return FieldType.tick;
      default:
        return FieldType.text;
    }
  }
}
