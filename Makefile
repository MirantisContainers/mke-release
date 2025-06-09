.PHONY: install-jsonschema validate-json

install-jsonschema:
	python3 -m venv .venv
	. .venv/bin/activate && pip install jsonschema

validate-json: install-jsonschema
	. .venv/bin/activate && python3 release-matrix/validate_json.py release-matrix/release-matrix.json release-matrix/release-matrix-schema.json
