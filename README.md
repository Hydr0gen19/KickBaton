# Kicker

Interrupt rotation assignments by raid marker, for World of Warcraft: Midnight (12.x).

Decide who covers which markers, share it with the group, and everyone gets a small
board telling them whose turn it is.

---

## Read this first: what Kicker cannot do

Midnight closed most combat state off to addons:

- `COMBAT_LOG_EVENT_UNFILTERED` errors on registration;
- **`GetRaidTargetIndex` is restricted for enemy units** — an addon cannot read which
  markers exist;
- creature names, GUIDs and enemy cast spell IDs are *secret values* inside an
  instance, and a secret cannot be compared: `if marker == 8` raises a Lua error
  rather than evaluating to false.

**So Kicker never sees the skull, and never knows it is casting.** It will not tell
you to press your interrupt. The division of labour is:

| Who | What |
|---|---|
| Your eyes | "There is a skull and it is casting" — the default nameplate already shows both |
| Kicker | "On the skull it is Marco's turn now, not Luca's" |

Kicker does not replace the eye. It replaces the memory and the voice call, which is
the part that actually cost effort.

---

## Install

Drop the `Kicker` folder into `World of Warcraft\_retail_\Interface\AddOns\`, so that
`AddOns\Kicker\Kicker.toc` exists. `/reload`, then `/kicker status` to confirm.

Everyone in the group needs it: both the assignment sync and the kick detection only
work between clients that have it.

---

## How it works: squads

A **squad** is a set of markers, an ordered list of players, and **one shared turn**.

```
Squad 1 — [Skull][Star] — Luca » Marco
Squad 2 — [Cross]       — Anna » Giulio
```

When Luca kicks, the turn passes to Marco across *both* of that squad's markers.

This is what removes the ambiguity. The addon cannot know which mob Luca kicked — that
information is off limits — but it does not need to. It only needs to know *that* Luca
kicked, and who comes after him.

Two invariants, enforced by the editor:

- a player belongs to **at most one squad**;
- a marker belongs to **at most one squad**.

The first is load-bearing. If a player sat in two squads, an incoming kick would be
impossible to attribute, and the ambiguity would be unresolvable rather than merely
awkward.

The classic "two people on one marker" is just a squad with a single marker.

### Configuring

`/kicker`, or right-click the board.

**New squad**, then **Add from group** for members. Use that button rather than typing
names: assignments are stored as `Name-Realm`, and the button takes the realm from the
group. Typed by hand across realms, names will not match and the rotation never fires.

Member order is turn order. Then click the markers that squad covers; markers already
taken by another squad are disabled.

---

## Reading the board

```
🔴🟣   » Marco | Anna 12
```

- the squad's markers on the left
- **`»` and a full class colour** — up now
- **a dimmed name** — ready, but not their turn
- **a grey name with a number** — on cooldown, seconds remaining
- **a highlighted row** — your squad

Drag it anywhere. `/kicker scale 1.5` to resize (0.5 to 3.0).

---

## Sharing assignments

Two channels for two different moments:

| | Push (addon message) | Export/import (string) |
|---|---|---|
| When | Live, group assembled | Beforehand, out of game |
| Who acts | Only the sender | Both ends |
| Needs a group | Yes | No |
| Needs lead | Yes | No |
| Carries the profile name | No | Yes |

**Push** keeps an assembled group in step. Swap markers between pulls, someone changes
character, someone joins mid-session — one click and everyone updates. Two cases are
automatic: the leader re-pushes on roster changes, and a joining client requests a sync.

**Export/import** gets the assignments to people in the first place. You do not paste
strings mid-key.

Push does **not** carry the profile name — squads land in the receiver's active
profile. The export string does, and recreates the profile on the other side.

---

## Macros

`/kicker macro` picks your marker (defaulting to your squad's first) and generates:

```
#showtooltip
/focus [@mouseover,harm,exists][]
/tm [@focus] ~3
```

```
/tm [@focus] 0
/clearfocus
```

The choice is saved per character. Anyone in a party can mark; a raid needs lead or
assist.

### If you had the old macros

`/run SetRaidTarget(...)` no longer works. `SetRaidTarget` became **Protected** in
12.0 — secure code only, so not from `/run` — and `GetRaidTargetIndex` on enemies is
restricted, so the familiar

```
/run if not GetRaidTargetIndex('focus') then SetRaidTarget('focus',1) end
```

fails at both the read and the write.

The replacement is native and better: `/tm` takes secure command options, and a `~`
prefix means *apply this marker unless someone else already marked the unit* — exactly
the condition that line was hand-rolling.

Order matters when clearing: `/tm [@focus] 0` must come **before** `/clearfocus`, or
`@focus` no longer resolves and the marker stays on the mob.

Kicker only ever *shows* this text. `RunMacroText` is as protected as `SetRaidTarget`,
and pretending otherwise would only move the error into the dungeon.

---

## Commands

Short alias: `/kk`.

| Command | Effect |
|---|---|
| `/kicker` | Open the squad editor |
| `/kicker help` | List commands |
| `/kicker status` | Report what the addon can and cannot do here |
| `/kicker macro` | Focus and marking macros |
| `/kicker push` | Send squads to the group (lead/assist only) |
| `/kicker export` / `import` | Share squads as a string |
| `/kicker profile <name>` | Switch profile (creates it if new) |
| `/kicker profile delete <name>` | Delete a profile you are not using |
| `/kicker next` | Advance your squad's turn manually |
| `/kicker show` / `hide` | Toggle the board |
| `/kicker lock` / `unlock` | Stop or allow dragging |
| `/kicker scale <0.5-3.0>` | Resize the board |
| `/kicker reset` | Recentre the board |

Three keybindings under Options → Keybindings → Kicker. Options (scale, lock, sound,
flash, automatic detection) under Options → AddOns → Kicker.

Profiles are account-wide and each holds its own squads. Switching to a new one
creates it empty; switch back and your squads return. To duplicate one, export and
import under a different name.

---

## Design notes

Two principles hold everywhere in the code:

**1. Never read another player's or an enemy's state.** Each client watches only
itself — `RegisterUnitEvent` scoped to `player` and `pet` — and *tells* the group about
its own kick. Nobody reads anyone else's cooldown; they declare it. This sidesteps the
12.1 change that disabled friendly cooldown tracking, and it is more accurate as a side
effect, since only you can know your own real cooldown.

**2. The marker never enters the logic.** It is never read, inferred or compared: it is
a label the user configures and the addon draws. Rotation runs entirely on the *sender*
of an addon message, which is unprotected data.

### Protocol

```
A|BEGIN|<revision>|<squadCount>|<force>
A|S|<index>|<markers csv>|<members csv>
A|END|<revision>
K|<cooldownSeconds>
Q                                          request a push from whoever leads
```

Prefix `KICKER`, 255 characters per message, 10-message burst with 1/second refill. A
full push is two framing messages plus one per squad: at most 10, so it never queues.

Squad lines accumulate in a per-sender buffer and are committed only on a well-formed
`END`, so a truncated push leaves the local configuration untouched.

`force` separates the two kinds of push. Automatic ones defer to the revision counter
and cannot clobber newer data; a deliberate *Push to group* always wins — if someone
else takes lead their revision may well be lower than what is already circulating, and
a push that silently does nothing is worse than useless.

The kick message names neither marker nor squad: `CHAT_MSG_ADDON` already supplies the
sender, and the receiver resolves the squad with `Squads:FindSquadOf(sender)`.

### Export format

```
Kicker:1:Mythic:2!1,8=Luca-Nemesis,Marco-Pozzo!7=Anna-Nemesis,Giulio-Pozzo
 magic ^ver ^profile  ^count  ^ one chunk per squad, markers=members
```

Plain text rather than serialise+compress+base64: the payload is a handful of names, so
compression buys nothing, and a format you can read at a glance is one you can debug
from a pasted message.

The squad count in the header exists to catch truncation — a chat client that clips a
long string would otherwise yield a smaller but perfectly valid assignment set, and
import it silently. Import also re-checks both invariants, because a string from
outside has never been through the editor. If any check fails, nothing is written.

---

## Development

```bash
npm install        # once
npm run verify     # before every sync
```

`npm run check` parses every Lua file as Lua 5.1, the version WoW runs — this catches
the class of mistake that otherwise only shows up as "the addon does not load".
`npm test` runs `Core/Transfer.lua` and `Core/Squads.lua` inside a real Lua VM against
stubs for the WoW API: export/import round trip, line-wrapped paste, unknown format,
truncation, duplicate marker, duplicate member, out-of-range marker, and that a
rejected import writes nothing.

The rest touches too much of the WoW API to test outside the game; there the safety net
is the parser plus `/kicker status`. For runtime errors, BugSack and !BugGrabber.

`sync.ps1` copies the addon into your AddOns folder, locating it automatically. Pass
`-Target` or set `WOW_ADDONS` to override.

### Values that age fastest

- **`## Interface`** in the `.toc` — currently `120007, 120100`. Confirm with
  `/dump select(4, GetBuildInfo())`.
- **Interrupt spell IDs** in `Core/Data.lua` — confirm with
  `/dump C_Spell.GetSpellInfo(<id>)`, and check the live watch list with
  `/kicker status`.

### Known risks

Self-report may be hit by future restrictions. The mitigation is structural rather than
reactive: `SelfReport` disables itself inside a `pcall` if registration fails, leaving
the manual keybinding and the board, neither of which depends on anything protected.
The test that protects the project is turning automatic detection off and confirming
everything else still works.

Blizzard has also relaxed some restrictions and introduced spell whitelists, so the
picture is not moving in one direction only.

---

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).

You are free to use, modify and redistribute it. If you distribute a modified
version, it has to stay open under the same licence.
