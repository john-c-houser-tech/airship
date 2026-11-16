# Airship

A focus timer that becomes a steampunk game, in Godot 4 with typed GDScript.
The plan (milestones, gates, decisions) is John's Claude Doc
https://claude.ai/artifact/YXeSesWeGS8YsdaMAv7qUc ; read it before starting a
milestone. Airship follows Grove (github.com/john-c-houser-tech/grove,
archived), whose rules and tests are the spec for Airship's rules.

## Files

- `project.godot`, `main.tscn`, `main.gd`: the project and the window. The
  window gives the core time and keys, shows the events it returns, and sets
  the frame rate (30 while the arm moves, a few while it rests, next to
  nothing between sessions). Keep the `.uid` files Godot writes beside
  scripts; commit them.
- `desktop/` is the one small Omarchy layer: the theme's accent
  (`theme.gd`) and `notify-send` (`notifier.gd`).
- `i18n/<code>.json` translate the English on screen, one file per Omarchy
  language code. Every line shown goes through `translate()` (or the app's
  `say()`), and the tests fail if any language lacks it or keeps a string
  nothing says any more: a new line needs all six translations.
- `scene/` draws. `hangar.gd` is the scene decided at gate B and after the
  milestone 5 mock-ups: inside the hangar beside the airship's front third,
  looking out the big door. It takes the daylight, the weather, the
  airship's progress (`App.airship_progress()`, from the parts the garden has made) and
  the garden's plants (the kinds that stand, and those left to rust) from the core, and draws only when they change, into
  two cached pictures (replaying it each frame cost 69% of a core): the
  outside (sky, land, railway) and the inside (the garden, the hangar and
  the airship, clear where the door shows the outside). `passers.gd` draws
  between them: the night train on the railway and the airship crossing the
  sky by day, each while its sound plays, every frame from how far into the
  sound it is (and, as still pictures, a visiting airship moored at the valley's mast
  for the break it brings a commission in, and the train standing at the station
  past the crossing,
  which `hangar.gd` draws in the outside picture, while it offers a
  trade); and `falling.gd`, rain and snow moving while the arm works
  (still, painted into the inside picture, between sessions). The
  workshop corner stands on the hangar's floor in the left foreground, seen
  through the same camera (`corner_canvas.gd`): `machinery.gd` (boiler,
  planter, parts bin) is drawn when the hangar is, `workshop.gd` (the arm and
  plant) every frame while the arm works. `hud.gd` holds the words.
- `core/` holds the rules, which draw nothing and run no timers: `app.gd`
  ties them together and returns events saying what changed;
  `options.gd` is the only reader of the environment (the `AIRSHIP_*`
  test knobs). `parts.gd` is the economy: five kinds of plant by blueprint,
  each making its part once per later completed session, and the parts an
  airship needs; parts made are worked out from the garden's plants, and
  the garden file keeps the parts fitted, those traded, which rusted plants
  were scraped clean, and the valley (airships launched; each plant
  remembers its own). The break after a session is `App.break_step()`:
  plant, scrape, collect and fit, one click or Enter each, then a trade
  if one is offered; once every part
  is fitted the launch is offered, and only the key L sets it off (it
  can't be undone).
  A launch starts a new valley: a fresh garden and airship, the old
  plants kept as history. The flight is the hangar's own ship, painted
  alone (`Hangar.Painting.SHIP`) every frame while it lasts (30 a second),
  by two layers split at the door: the part still inside over the hangar's
  picture, the part beyond the door under it.
  Each valley has its own range, hills, grass and cloth, worked out from
  its number in `hangar.gd` (`valley`, `VALLEYS`, `_roll`); the first is
  as it always was.
  The night train trades in the break (`Parts.trade`): after every fifth
  completed session it calls, for that break only, with one trade of three parts the garden can best
  spare for one it is slowest to make (a boiler drum), offered last in
  the break and only on T or a click through the door, so it can be left; the garden file keeps what was given and brought
  and the sessions completed at the last trade (version 4 from the first
  trade).
  `commissions.gd`: a visiting airship asks for plants built a certain
  way (kind and weather), one commission at a time and no deadline;
  each met wins a pennant, hung under the door's lintel (`hangar.gd`).
  The airship that brings one is moored outside for that break
  (`passers.gd`). Nothing is saved for them: it all follows from the
  valley's plants.
  Blueprints unlock as the airship grows; Left and Right choose the next
  plant (`App.choose`), and `workshop.gd` lays out each kind's parts.
  Grove's `src/*.rs` rules and their tests are the spec.
- `tests/test_*.gd` are the unit tests: each extends `TestCase`
  (`tests/test_case.gd`) and each `test_*` method is one test.
  `tests/run.gd` runs them all and exits 1 on any failure.
- `tools/make_sounds.gd` synthesizes the two distant sounds (a steam train
  at night, an airship by day) into `sounds/`, which is never committed:
  each remake would stay in git's history for good. `bin/make-sounds` runs
  it (once, to hear sounds when running from the repo); `bin/test` and the
  package build run it too. Without the files Airship is simply quiet.
- `pkgbuild/` packages Airship for Arch: one data file (`airship.pck`,
  exported by the `Linux` preset in `export_presets.cfg`) that Arch's
  `godot` runs through the `airship` launcher, with a desktop entry, an
  icon (milestone 5's; checked against look-alikes: the Airship company's
  blue mark and OpenStack Airship's silhouette-over-an-A) and a pacman hook that
  speaks up when Godot is upgraded. `bin/install` builds and installs it.
  `pkgver` and `config/version` in `project.godot` must match (bin/test
  checks), and bin/test runs the exported file in German with a train.
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
