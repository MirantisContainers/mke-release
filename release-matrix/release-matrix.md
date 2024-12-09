This directory contains the release matrix for MKE 4. The matrix maps an MKE 4 minor/patch version to the corresponding component versions that are tied to that release.

The `release-matrix.json` file should be updated whenever a new MKE 4 version is released.

Compatibility can be checked by running the following `make` command:

```bash
make validate-json
```

Or it can be run manually with the `check-jsonschema` CLI:

```bash
check-jsonschema --schemafile release-matrix-schema.json release-matrix.json
```

NOTE: `check-jsonschema` needs to be installed first by following the instructions on https://pypi.org/project/check-jsonschema/.