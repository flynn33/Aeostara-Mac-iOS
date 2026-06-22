# Aeostara Baseline Reference

| Field | Value |
|---|---|
| Source repository | `flynn33/aeostara` |
| Release tag | `v1.0.0` |
| Release commit | `b51ef8d018e82cc073c30813804795a2b7695fa9` |
| ASH baseline commit | `e123f5d7fdbb381179971f721a3292c31eb1cbc2` |
| Base package | `aeostara-base-design-v1.0.0.zip` |

## Verification

The pinned base release is verified by resolving `flynn33/aeostara:v1.0.0` and comparing it with `b51ef8d018e82cc073c30813804795a2b7695fa9`.

```text
git ls-remote --tags https://github.com/flynn33/aeostara.git 'v1.0.0^{}'
```

The contract inventory is verified from the pinned release with the source repository command:

```text
python3 ci/validate_schemas.py .
```
