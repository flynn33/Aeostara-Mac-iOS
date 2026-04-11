# Wiki Automation

## Purpose

Define how Aeostara wiki content is generated, maintained, and refreshed across branches.

## Wiki Agent

Primary maintenance agent:

- Workflow: `.github/workflows/wiki-sync.yml`
- Trigger: push to any branch + manual dispatch
- Generator: `.github/scripts/generate_wiki_pages.py`

Responsibilities:

1. Build branch-scoped overview dashboards.
2. Wrap source docs/contracts/interfaces into consistent wiki page layouts.
3. Maintain branch index and wiki `Home.md`.
4. Keep links and metadata deterministic.

## Maintenance Sweep Agent

Periodic cross-branch refresh agent:

- Workflow: `.github/workflows/wiki-maintenance-sweep.yml`
- Trigger: daily schedule + manual dispatch
- Scope: `main`, `platform/windows`, `platform/macos`, `platform/ios`

Responsibilities:

1. Regenerate all primary branch wiki pages even if branch push cadence differs.
2. Keep branch dashboards synchronized to latest branch heads.
3. Prevent stale branch pages in the wiki knowledge base.

## Visual Structure Requirements

Generated branch overview pages must include:

- Snapshot metadata table (branch, commit, sync time)
- Branch map diagram
- Coverage table (docs/contracts/algorithms/interfaces/acceptance)
- Category navigation sections
- Back-links from leaf pages to branch overview

## Determinism Requirement

Given identical source tree and commit, the generator must produce identical wiki output.
