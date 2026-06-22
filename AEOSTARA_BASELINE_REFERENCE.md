# Aeostara Baseline Reference

| Field | Value |
|---|---|
| Source repository | `flynn33/aeostara` |
| Release tag | `v1.0.0` |
| Release commit | `dfa401fa1826a73f5747dd83c74ff963e15eb32f` |
| ASH baseline commit | `e123f5d7fdbb381179971f721a3292c31eb1cbc2` |
| Base package | `aeostara-base-design-v1.0.0.zip` |

## Verification

The pinned base release is verified by resolving `flynn33/aeostara:v1.0.0` and comparing it with `dfa401fa1826a73f5747dd83c74ff963e15eb32f`.

```text
git ls-remote --tags https://github.com/flynn33/aeostara.git 'v1.0.0^{}'
```

The contract inventory is verified from the pinned release with the source repository command:

```text
python3 ci/validate_schemas.py .
```
