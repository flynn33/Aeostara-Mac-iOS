# Branch Isolation Rules

- `main` contains repository coordination material only.
- `platform/macos` and `platform/ios` are permanent implementation branches.
- Implementation branches must not be merged into coordination `main`.
- Implementation branches must not be merged into each other.
- Shared semantic changes must originate in the external Aeostara base-design repository and be applied independently to each implementation branch.
