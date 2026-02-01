#!/usr/bin/env python3
import json
import sys

def main():
    filepath = '/Users/sami/project/micell/Scribe-replacement/JRCALC_Protocols.json'

    print(f"Parsing JSON from {filepath}...")

    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"JSON parse error at line {e.lineno}: {e.msg}", file=sys.stderr)
        with open(filepath, 'r') as f:
            error_lines = f.readlines()
            start = max(0, e.lineno - 3)
            end = min(len(error_lines), e.lineno + 2)
            for i in range(start, end):
                marker = ">>>" if i == e.lineno - 1 else "   "
                print(f"{marker} {i+1}: {error_lines[i].rstrip()}", file=sys.stderr)
        sys.exit(1)

    if 'protocols' not in data:
        print("Error: Expected 'protocols' key at root level", file=sys.stderr)
        sys.exit(1)

    protocols = data['protocols']
    print(f"\n✓ JSON valid! Total protocols: {len(protocols)}\n")
    print("Protocol Summary:")
    print("-" * 80)
    print(f"{'condition_id':<30} {'name':<25} {'category':<15} {'steps'}")
    print("-" * 80)

    for protocol in protocols:
        condition_id = protocol.get('condition_id', 'N/A')
        name = protocol.get('name', 'N/A')
        category = protocol.get('category', 'N/A')
        steps = len(protocol.get('steps', []))
        print(f"{condition_id:<30} {name:<25} {category:<15} {steps}")

    print("-" * 80)

if __name__ == '__main__':
    main()
