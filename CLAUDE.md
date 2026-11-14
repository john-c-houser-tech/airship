# Airship

A focus timer that becomes a steampunk game, in Godot 4 with typed GDScript.
The plan (milestones, gates, decisions) is John's Claude Doc
https://claude.ai/artifact/YXeSesWeGS8YsdaMAv7qUc ; read it before starting a
milestone. Airship follows Grove (github.com/john-c-houser-tech/grove,
archived), whose rules and tests are the spec for Airship's rules.

## Files

- `project.godot`, `main.tscn`, `main.gd`: the project and its main scene.
  Keep the `.uid` files Godot writes beside scripts; commit them.
- `core/` holds the rules, which draw nothing and run no timers: `app.gd`
  ties them together and returns events saying what changed;
  `options.gd` is the only reader of the environment (the `AIRSHIP_*`
  test knobs). Grove's `src/*.rs` rules and their tests are the spec.
- `tests/test_*.gd` are the unit tests: each extends `TestCase`
  (`tests/test_case.gd`) and each `test_*` method is one test.
  `tests/run.gd` runs them all and exits 1 on any failure.
- `prototypes/` holds the throwaway tests of milestones 1 to 3.
- `bin/test` runs every check. It never opens a window on the desktop: it runs
  headless, and draws frames under `xvfb-run` (package `xorg-server-xvfb`).
  Any ERROR or WARNING line from Godot fails it.
- `.github/workflows/ci.yml` runs `bin/test` on every PR, in Arch from
  Omarchy's stable mirror, and keeps the frame as a run artifact.

## Rules for agents

- Never open Airship, or any window, on the user's desktop: it takes their
  focus while they type. Look at frames from `bin/test` or `--shot=<path>`.
- Typed GDScript only: untyped declarations are errors (`project.godot`).
- Every frame comes from its inputs (session progress, clock, date, weather,
  a seed). No state carried between frames, no timers driving the scene.
- Dependencies stay on their current release.
- Commit only when asked.

## Budget

John watches what each session costs.

- Name a milestone's size (S, M, L in the plan) before starting it, and say
  when work runs past it.
- Stop at every gate in the plan; John decides before the next milestone.
- Prototypes (milestones 1 to 3) are throwaway: placeholder art, no reviews,
  no packaging, no CI polish.
- No multi-agent workflows. Reviews: one independent agent review per PR from
  milestone 4 on, two for threads, saved data or changes to how the garden is
  stored.
- Read only what the step needs; run slow checks once, at the end.
- End each session with a short resume note in memory.

## Git

The repository is https://github.com/john-c-houser-tech/airship (public).
`main` is John's: never commit or push to it, and never force-push. `dev` is
the integration branch.

1. Before any new work: `git checkout dev && git pull --ff-only`.
2. Branch from dev; check `git branch --show-current` before every commit.
3. Push the branch and open a PR into dev: `gh pr create --base dev`.
4. Wait for CI: `gh pr checks <n> --watch`. main's ruleset requires the
   `CI result` check; keep that job's name.
5. John merges to dev and to main.
