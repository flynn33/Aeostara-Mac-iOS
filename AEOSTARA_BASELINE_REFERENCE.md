# Aeostara Baseline Reference

| Field | Value |
|---|---|
| Source repository | `flynn33/aeostara` |
| Release tag | `v1.0.0` |
| Release commit | `774b981ef2267a41c1b1a59497b2b0746a86f32b` |
| ASH baseline commit | `e123f5d7fdbb381179971f721a3292c31eb1cbc2` |
| Base package | `aeostara-base-design-v1.0.0.zip` |

## Verification

The pinned base release is verified by resolving `flynn33/aeostara:v1.0.0` and comparing it with `774b981ef2267a41c1b1a59497b2b0746a86f32b`.

```text
git ls-remote --tags https://github.com/flynn33/aeostara.git 'v1.0.0^{}'
```

The contract inventory is verified from the pinned release with the source repository command:

```text
python3 ci/validate_schemas.py .
```
