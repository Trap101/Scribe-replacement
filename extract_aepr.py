#!/usr/bin/env python3
"""Extract and summarize all fields from AEPR_Attributes.json"""

import json

TYPE_MAP = {
    "Local List": "dropdown",
    "Numeric": "number",
    "Alphanumeric": "text",
    "Date": "date",
    "Time": "time",
    "Coordinate": "text",
}

def main():
    with open("AEPR_Attributes.json", "r") as f:
        data = json.load(f)

    root = data["AEPR_Standard_v1.0"]
    total_fields = 0
    sections = {}

    for section_name, fields in root.items():
        section_fields = []
        for field_key, field_data in fields.items():
            flutter_type = TYPE_MAP.get(field_data.get("type", ""), "text")
            values = field_data.get("values", [])
            # Filter placeholder values
            if values == ["INSERT LOCAL LIST HERE"] or values == ["INSERT LOCAL LIST HERE", "All drugs captured as SNOMED"]:
                values = []

            section_fields.append({
                "section": section_name,
                "key": field_key,
                "id": field_data.get("id"),
                "flutter_type": flutter_type,
                "description": field_data.get("description", ""),
                "values": values,
            })
            total_fields += 1

        sections[section_name] = section_fields

    print(f"AEPR Standard v1.0 - Field Extraction Summary")
    print(f"=" * 55)
    print(f"Total sections: {len(sections)}")
    print(f"Total fields:   {total_fields}")
    print()

    type_counts = {}
    for sec_fields in sections.values():
        for f in sec_fields:
            t = f["flutter_type"]
            type_counts[t] = type_counts.get(t, 0) + 1

    print("Field type distribution:")
    for t, c in sorted(type_counts.items(), key=lambda x: -x[1]):
        print(f"  {t:12s}: {c}")
    print()

    print("Sections and field counts:")
    for name, fields in sections.items():
        print(f"  {name:50s} {len(fields):3d} fields")

if __name__ == "__main__":
    main()
