import json
import jsonschema
import sys

def validate_json(json_file, schema_file):
    with open(json_file, 'r') as f:
        data = json.load(f)
    with open(schema_file, 'r') as f:
        schema = json.load(f)
    jsonschema.validate(instance=data, schema=schema)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python validate_json.py <json_file> <schema_file>")
        sys.exit(1)
    json_file = sys.argv[1]
    schema_file = sys.argv[2]
    validate_json(json_file, schema_file)
    print("JSON validation successful.")