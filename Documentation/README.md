# Nexus Documentation — Index & Reader's Map

This folder is the project's source of truth. It is written for two readers:
**humans** and **AI coding agents** (Codewhale on Claude or DeepSeek, and
similar). Agents: read only the file the task calls for — see the decision
table below, then the narrower maps in `AGENTS.md` and
`.codewhale/instructions.md`.

## File map

| File | Purpose | Read when |
|---|---|---|
| `AGENTS.md` | Agent operating guide: repo at a glance, workflow, commit rules, Definition of Done, invariants | Start of any task (Codewhale: `.codewhale/instructions.md` is the short injected summary) |
| `architecture.md` | Architecture blueprint / porting guide (1,300+ lines). §14 = one-paragraph summary; §13 Step 8 = invariants checklist | Any architecture-sensitive change — read only the § for the layer you touch |
| `features.md` | Product scope ("the what") | Feature work, scope questions |
| `ROADMAP.md` | Releases, milestones, scope decisions (§5 resolves doc conflicts — architecture.md wins) | Milestone/planning questions |
| `tasks.md` | Day-by-day task breakdown with checkboxes; the live project state | "Where are we / what is next?" — confirm with `git log` |
| `CONTRIBUTING.md` | Conventional Commits spec, branches, PR process, setup, testing | Writing a commit or opening a PR |
| `README.md` | This index | Orientation |
| `appspec.md` | App **behavior** spec: per-feature rules, flows, acceptance criteria | Feature work needing behavior detail — read only the § for your feature; §2.2 (Card Controls) is the worked example |
| `CHANGELOG.md` | Release notes | **Empty on purpose** — written at v1.0 (Day 15, tasks.md M8) |

## Decision table (short form)

- **New task** → `AGENTS.md`.
- **Feature work** → the `architecture.md` section for the layer (§4 Domain,
  §6 Data, §9 Features, §11 app target) + `CONTRIBUTING.md` for the commit.
- **Feature behavior** → `features.md` for scope, then the matching
  `appspec.md` §2.x for that feature's rules and acceptance criteria.
- **Docs change** → update the matching file above and anything it points to.
- **"Where are we?"** → `tasks.md` checkboxes + `git log` (dated prose
  status blocks rot; trust checkboxes and commits).

## Conventions

- **Status claims rot.** Prefer checkboxes (`tasks.md`) and git history over
  "as of <date>" prose. When a status block is unavoidable, date it and keep
  it to three lines.
- **Rules live once.** Do not copy a rule from one file into another —
  link instead. Duplicated rules drift and contradict each other.
- **One concern per file.** If a topic has no home, the index above is
  where the map changes first.

## Repo root

The app code lives at the workspace root: `Nexus.xcworkspace`,
`AppPackages/` (the three SPM packages), the `Nexus/` app target, and
`TestPlan.xctestplan`. Root `README.md` and `CHANGELOG.md` are created at
v1.0 (see `tasks.md`).
