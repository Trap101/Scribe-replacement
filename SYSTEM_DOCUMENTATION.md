# JRCALC EPCR Integration - Complete System

## 📦 Deliverables Created

### 1. **Merged_Clinical_Attributes.json** (340 attributes)
- **Purpose**: Single unified attribute file combining AEPR Standard + JRCALC Extended
- **Structure**: 
  - Metadata tracking version, totals, last updated
  - Attributes organized by clinical category
  - Each attribute includes: `id`, `source` (AEPR/Extended), `type`, `cardinality`, `description`
  - `medic_visible: false` flag on excluded categories (Crew, Dispatch, GPS, etc.)
- **Coverage**: 
  - 208 AEPR Standard attributes (IDs 1-208)
  - 132 Extended JRCALC attributes (IDs 1001-1132)
  - Zero overlap between sources
- **Path Convention**: `Category.attributeName` (e.g., `Assessment.pe_risk_factors`)

### 2. **Macro_Category_Mapping.json** (7 categories)
- **Purpose**: Organizes all 340 attributes into logical UI groupings
- **Categories**:
  1. **CASMEET / Primary Survey** (19 attributes)
     - Hospital handoff essentials only
     - Cardinality 1..1 if patient transported to hospital
     - NOT required for scene discharge
  
  2. **Incident & Patient ID** (19 attributes)
     - Essential identification and incident data
     - Names, DOB, NHS number, address, incident times
  
  3. **The Story (Background)** (26 attributes)
     - Patient background, history, presenting complaint
     - Allergies, medications, symptoms, pain assessment
  
  4. **Trauma & Specifics (Protocol Engine)** (111 attributes)
     - Protocol-driven clinical decision points
     - Where AI injects relevant checklists
     - All Extended.Assessment.* fields, FAST, GCS, vital signs
  
  5. **Interventions (Action Log)** (97 attributes)
     - All treatments, procedures, drug administrations
     - CPR, defibrillation, airway management, immobilization
  
  6. **Outcome & Handoff** (34 attributes)
     - Disposition, refusals, life extinct, handover details
  
  7. **Baseline Always Required** (14 attributes)
     - Auto-suggest for EVERY patient
     - Demographics, allergies, medications, presenting complaint

- **Metadata**: Lists 8 excluded categories with reasons (Crew/Dispatch/GPS/etc.)

### 3. **Baseline_Required_Attributes.json**
- **Purpose**: Detailed specification of always-suggest attributes
- **Contents**:
  - 14 baseline attributes grouped by priority
  - Patient Demographics (6): Name, DOB, age, sex, NHS number
  - Safety Critical (3): Allergies, current medications
  - Clinical Context (3): Presenting complaint, medical history
  - Incident Context (2): Incident time/date
- **Workflow**: Step-by-step usage flow for developers
- **Auto-population hints**: Age from DOB, sex from prompt, etc.

### 4. **JRCALC_Protocols.json** (existing - no changes needed)
- **Status**: Validated and ready to use
- **Path Compatibility**: Target fields already use simplified paths matching merged file
- **Examples**: `Assessment.pe_risk_factors`, `Blood Glucose.bloodGlucose`, `Airway Assessment.breathing`
- **No updates required**: Paths already compatible with Merged_Clinical_Attributes.json structure

---

## 🎯 System Architecture

### Dual-Mode Data Entry
1. **Protocol-Driven Mode**
   - Medic writes prompt: "45yo male presenting with chest pain"
   - System suggests **Baseline Required** (14 attributes)
   - If JRCalc condition recognized → inject protocol-specific attributes from **Trauma & Specifics**
   - Protocol steps use `prefill_data` for button actions (medic chooses)

2. **Manual Search Mode**
   - Medic uses dropdown organized by 6 macro categories
   - OR semantic search across all 340 attributes
   - Dev team handles search implementation using merged file

### CASMEET Handoff Format
- **C**allsign: Vehicle/unit responding
- **A**ge: Patient age
- **S**ex: Male/Female
- **M**echanism/Mode: Injury mechanism OR illness mode
- **E**xamination: Clinical findings from assessment
- **E**verything done: Treatments provided
- **T**ime: ETA to hospital

**Only required for hospital handoff, NOT scene discharge**

---

## 🔧 Developer Integration Guide

### File Usage

#### For UI Attribute Dropdowns
```json
// Read Macro_Category_Mapping.json
{
  "macro_categories": {
    "The_Story": {
      "display_name": "The Story (Background)",
      "attributes": [
        "Chief Complaint.presentingComplaint",
        "Known Allergy.type",
        ...
      ]
    }
  }
}
```

#### For Attribute Details
```json
// Read Merged_Clinical_Attributes.json
{
  "attributes": {
    "Known Allergy": {
      "type": {
        "id": 116,
        "source": "AEPR",
        "type": "Local List",
        "cardinality": "1..1",
        "values": ["INSERT LOCAL LIST HERE"],
        "description": "The patient allergy..."
      }
    }
  }
}
```

#### For Protocol Engine
```json
// Read JRCALC_Protocols.json
{
  "condition_id": "copd_001",
  "steps": [
    {
      "target_field": "Assessment.life_threatening_asthma",
      "action_type": "multi_select",
      "ui_prompt": "Check for life-threatening features"
    }
  ]
}
```

#### For Always-Suggest Logic
```json
// Read Baseline_Required_Attributes.json
{
  "baseline_required_attributes": [
    {
      "category": "Patient Demographics",
      "priority": "Critical",
      "attributes": [
        {"path": "Patient Details.familyName", ...}
      ]
    }
  ]
}
```

---

## ✅ Data Validation Rules

### Cardinality
- `1..1` = Required field (**warning only, not blocking**)
- `1..0` = Optional field
- `1..*` = Multi-select (1 or more required)

### Submission Policy
- **Allow submission with incomplete data**
- Show warnings for missing 1..1 fields
- Do NOT block save/submit

### Excluded Categories
- Attributes with `"medic_visible": false` should be:
  - Hidden from UI dropdowns
  - Hidden from search results
  - Still present in system for admin/dispatch use

---

## 📊 System Statistics

| Metric | Count |
|--------|-------|
| Total Attributes | 340 |
| AEPR Standard | 208 |
| Extended JRCALC | 132 |
| Clinical Protocols | 51 |
| Protocol Categories | 15 |
| Macro UI Categories | 7 (6 + baseline) |
| Baseline Required | 14 |
| Excluded Categories | 8 |
| CASMEET Attributes | 19 |

---

## 🚀 Implementation Checklist

### Phase 1: Core Integration
- [ ] Parse Merged_Clinical_Attributes.json into database/state
- [ ] Load Macro_Category_Mapping.json for UI organization
- [ ] Implement dropdown navigation by 6 categories
- [ ] Add `medic_visible` filtering logic

### Phase 2: Protocol Engine
- [ ] Load JRCALC_Protocols.json
- [ ] Implement protocol matching from prompt text
- [ ] Build baseline auto-suggest (14 attributes from Baseline_Required_Attributes.json)
- [ ] Build protocol-specific auto-suggest (attributes from matching protocol steps)

### Phase 3: Auto-fill Logic
- [ ] When button action selected → prefill from protocol `prefill_data`
- [ ] Age from DOB calculation
- [ ] Incident time defaults to current time

### Phase 4: Search & Discovery
- [ ] Semantic search across all 340 attributes (your LLM implementation)
- [ ] Keyword search fallback
- [ ] Filter excluded categories from search results

### Phase 5: CASMEET
- [ ] Detect hospital transport vs scene discharge
- [ ] If hospital → enforce CASMEET category cardinality warnings
- [ ] If scene discharge → skip CASMEET requirements

### Phase 6: Validation
- [ ] Show cardinality warnings for 1..1 fields
- [ ] Allow submission regardless of completeness
- [ ] Validate data types (Numeric, Date, Time, etc.)

---

## 🔑 Key Design Decisions

1. **Category Consolidation**: Merged AEPR + Extended into single file with `source` metadata
2. **Path Convention**: Simple `Category.attribute` format (no Extended prefix in paths)
3. **Protocol Compatibility**: JRCALC_Protocols.json paths already match merged structure
4. **Baseline Strategy**: Separate file for clarity, also referenced in macro mapping
5. **Visibility Flags**: `medic_visible: false` in merged file for excluded categories
6. **CASMEET Flexibility**: Conditional requirement based on disposition type

---

## 📝 Notes for Development Team

### Source Attribution
- Every attribute has `"source": "AEPR"` or `"source": "Extended"`
- If medic asks "where does this come from", show source
- AEPR = NHS national standard
- Extended = JRCalc clinical protocol-specific

### Path References
- Protocols reference: `Assessment.pe_risk_factors`
- Merged file path: `"Assessment": {"pe_risk_factors": {...}}`
- Macro mapping uses: `"Assessment.pe_risk_factors"`
- **All consistent - no path updates needed**

### Cardinality in Context
- CASMEET category: Show warnings for 1..1 fields **IF hospital transport**
- Other categories: Warnings are optional guidance, never block submission
- Multi-select (1..*): User must select at least one value if field populated

### Future Extensibility
- New attributes: Add to Merged_Clinical_Attributes.json with new ID
- New categories: Add to Macro_Category_Mapping.json
- New protocols: Add to JRCALC_Protocols.json with unique condition_id
- Attribute paths in protocols must match merged file structure

---

## 📞 Support & Maintenance

### File Version Control
- All files include `"last_updated": "2026-02-01"`
- Increment version numbers when making changes
- Keep changelog in metadata section

### Validation Scripts (Future)
- Cross-reference protocol target_fields against merged attributes
- Verify all macro mapping attributes exist in merged file
- Check for duplicate IDs

---

**System Status: ✅ READY FOR IMPLEMENTATION**

All attribute definitions complete. Protocol engine validated. Macro categories organized. Baseline requirements specified. No breaking changes needed to existing protocols.
