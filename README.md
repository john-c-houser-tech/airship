# Airship

A focus timer that turns into a game: focus makes steam, a robotic arm builds
brass plants in a garden by the hangar, and the plants make the parts for an
airship you build inside a big wooden hangar. When it's finished, it flies out
through the doors and over the pass.

Airship follows [Grove](https://github.com/john-c-houser-tech/grove), a focus
timer for Omarchy, and keeps its mountain valley.

## How it plays

Press Space and stay with your work for 25 minutes while the arm builds a
plant. There is nothing to do during a session. In the break afterwards the
game asks for one small thing at a time: plant the new plant out in the
garden, collect the parts the older plants have made, fit them to the
airship. Skipping a break loses nothing.

- **Five plants** make the five kinds of part: cogs, copper tubing, struts,
  cloth and boiler drums. You choose which plant the arm builds next.
- **Giving up** a session leaves the half-built plant to rust in the garden.
  A later session's break can scrape it clean.
- **The night train** calls at the station after every fifth session and
  offers one trade, for that break only.
- **Visiting airships** bring commissions: plants built a certain way, with
  no deadline. Each one met hangs a pennant under the hangar door.
- **The launch:** when every part is fitted, the airship flies out through
  the door and over the pass, and a new valley begins with a new airship.

Only focus moves the game forward. There are no streaks, no countdowns and
no notices but the one at a session's end. Press H for help at any time.

## Install

On Arch (Omarchy), from this folder:

```
bin/install
```

It builds the package and installs it (makepkg asks for your password).
Airship then shows up in the app launcher. It needs the `godot` package, and
after a Godot upgrade it may need `bin/install` again (pacman reminds you
after each one).

To run it from the folder instead: `bin/make-sounds` once, then
`godot --path .`.

## Keys

| Key   | Action                                  |
|-------|-----------------------------------------|
| Space | Start 25 minutes of focus, or give up   |
| Left, Right | Choose the plant the arm builds next |
| Enter | Take the break's next step: plant, scrape, collect, fit (or click: the garden through the door, or the airship) |
| T     | Take the night train's trade, when it offers one (or click through the door) |
| L     | Launch the finished airship             |
| M     | Turn the sounds off or on               |
| H     | Unfurl the help banner, or roll it up (Esc or a click rolls it up too): what is happening and the keys that do something now |

Airship follows Omarchy's theme colour and language. Your garden is kept in
`~/.local/share/airship/garden.json`.

## Trying it out

From the repository, `bin/try` plays the game without the waiting: sessions
of ten seconds, in a garden of its own that starts at a stage of the game.
Your real garden is never touched.

| Command | Where it starts |
|---|---|
| `bin/try` | A new game. |
| `bin/try train` | One session before the night train first calls and the first commission comes. |
| `bin/try trade` | The train is at the station, offering a trade. |
| `bin/try pennant` | Two commissions met: pennants hang under the door's lintel. |
| `bin/try launch` | The airship is finished: press L. |
| `bin/try valley` | Just after a launch, in the second valley. |
| `bin/try again` | The same garden as you left it. |

A number after the stage sets the session's seconds: `bin/try trade 30`.
The settings below work with it: `AIRSHIP_TIME=23:00 bin/try trade`. Leave
`AIRSHIP_WEATHER` unset when trying commissions: with the weather pinned,
every plant is built in that weather, and a commission that asks for another
can't be met.

These pin what Airship would otherwise take from the clock and the desktop:

| Setting | What it does |
|---|---|
| `AIRSHIP_SECONDS=60` | A short session. It isn't saved to your garden unless `AIRSHIP_GARDEN` is set too. |
| `AIRSHIP_TIME=22:00` | Freeze the sky at that time. |
| `AIRSHIP_DATE=2026-01-10` | Pin the date, and so the season. |
| `AIRSHIP_WEATHER=snow` | Pin the weather: `clear`, `cloudy`, `rain`, `snow` or `fog`. |
| `AIRSHIP_GARDEN=/path/garden.json` | Use another garden file. |
| `AIRSHIP_LANGUAGE=de` | Use another language: `da`, `de`, `es-MX`, `fr`, `ja` or `pt-BR`. |
| `AIRSHIP_SOUND_TEST=train` | Play the `train` or the `airship` three seconds into the next session. |
| `AIRSHIP_SOUND_VOLUME=0.5` | Scale the sounds' volume, from 0 to 1. |

For example: `AIRSHIP_SECONDS=60 AIRSHIP_TIME=22:00 AIRSHIP_SOUND_TEST=train airship`
