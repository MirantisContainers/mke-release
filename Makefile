.PHONY: install-jsonschema validate-json

install-jsonschema:
	pip3 install jsonschema

validate-json: install-jsonschema
	python3 release-matrix/validate_json.py release-matrix/release-matrix.json release-matrix/release-matrix-schema.json