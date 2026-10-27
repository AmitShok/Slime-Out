<div align="center">

<img src="docs/logo.png" alt="SLIME-OUT" width="560">

### Survive the horde.

A pixel-art, round-based **horde-survival shooter** with roguelite upgrades —<br>
part *Vampire Survivors*, part *Enter the Gungeon*, all slime.

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-typed-355570)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6)
![Status](https://img.shields.io/badge/status-in%20development-ffcd75)

<img src="docs/screenshots/combat.png" alt="Slime-Out gameplay" width="860">

</div>

---

## Table of contents
- [About](#about)
- [Features](#features)
- [Screenshots](#screenshots)
- [The arsenal](#the-arsenal)
- [The horde](#the-horde)
- [Upgrades](#upgrades)
- [Controls](#controls)
- [Getting started](#getting-started)
- [Saves & settings](#saves--settings)
- [Project structure](#project-structure)
- [Content pipeline](#content-pipeline)
- [Credits](#credits)
- [License](#license)

## About

**Slime-Out** drops you into a fenced clearing deep in the forest with nothing but a Glock and a bad feeling. Slimes pour out of the trees in ever-larger waves. Clear a round, pick one of three upgrades, and go again. Every round is harder than the last, and every fifth round the **Slime King** comes to collect.

Upgrades never go to waste: they are stored as weapon-agnostic modifiers, so when you swap your pistol for an AK-47, a revolver or a rocket launcher, **every upgrade you own carries over** to the new gun.

## Features

**Core loop**
- Endless, escalating rounds — enemy count, health, speed and damage all scale per round, with spawn bursts that grow every three rounds.
- **Boss rounds** every 5 rounds featuring the crowned Slime King.
- **Pick 1 of 3 upgrades** after every round, weighted by rarity (Common / Rare / Epic), with weapon swaps offered on round-end picks.
- **XP gems & mid-round level-ups** — slimes drop gems that magnetise to you; level up mid-fight for an instant pick.
- **Auto-weapons** in the bullet-heaven tradition: guardian orbs, combat drones and sky lightning fight alongside you.
- **Dash with i-frames** — dash straight through the horde (with a short grace window and a satisfying *DODGE!*).

**Feel & visuals**
- Hand-made pixel art: hero, slimes, FX and UI drawn in Aseprite, plus a forest arena built from the Mystic Woods tileset.
- **Juice everywhere** (the Vlambeer recipe): muzzle flares, ejected brass casings, recoil, camera kick, smooth noise-based screen shake, hit-stop, damage numbers, goo splats that stay on the floor.
- **HDR bloom** on bullets, explosions, orbs, lightning and gems.
- **CRT post-processing** — curved glass, scanlines, aperture grille, chromatic aberration and vignette (adjustable or off).
- Living arena: wind-swayed foliage, drifting fireflies, flowers, mushrooms and winding dirt paths.

**Audio**
- Layered gunshots designed per weapon (mechanical click → crack → body → sub → outdoor tail), realistic reload foley and bouncing brass casings.
- Original 150 BPM gameplay track **"Slime Rush"**; a separate theme plays on the menus and pause screen.
- Positional sound, voice limiting for huge fights, and a rising pitch chain when vacuuming up gems.

**Quality of life**
- **Animated main menu** in "attract mode" — the hero holds the clearing behind a dripping, bouncing logo.
- **Continue your run**: quit mid-round and pick up exactly where you left off (enemies, pickups and all).
- **Build inspector** (`Tab`) showing every stat with your upgrades applied and everything you've picked.
- **Options menu** for audio buses, video, screen shake, hit-stop, damage numbers and a fully **custom crosshair** (5 styles, size, colours, spin, recoil kick, hit markers) with a live preview.

## Screenshots

| | |
|:---:|:---:|
| <img src="docs/screenshots/main_menu.png" alt="Main menu" width="420"> | <img src="docs/screenshots/boss.png" alt="Boss round" width="420"> |
| **Attract-mode main menu** | **The Slime King arrives** |
| <img src="docs/screenshots/level_up.png" alt="Level up" width="420"> | <img src="docs/screenshots/build.png" alt="Build inspector" width="420"> |
| **Level up — pick one of three** | **Build inspector** |
| <img src="docs/screenshots/options_crosshair.png" alt="Crosshair options" width="420"> | <img src="docs/screenshots/combat.png" alt="Combat" width="420"> |
| **Custom crosshair with live preview** | **Orbs, drones and incendiary rounds** |

## The arsenal

You start with the Glock. Other guns appear as upgrade choices once you reach their unlock round, and your upgrades always transfer.

| Weapon | Damage | Fire rate | Magazine | Reload | Special | Unlocks |
|---|---:|---:|---:|---:|---|:---:|
| **Glock P80** | 10 | 4 / s | 12 | 1.1 s | Reliable starter | Start |
| **Colt 45 Revolver** | 30 | 2 / s | 6 | 1.7 s | Pierces 1 enemy | Round 2 |
| **MP5A3 SMG** | 7 | 11 / s | 30 | 1.6 s | Bullet hose, loose spread | Round 2 |
| **AK-47** | 13 | 8 / s | 30 | 2.1 s | Pierces 1 enemy | Round 4 |
| **M20 Bazooka** | 40 | 1.1 / s | 3 | 2.4 s | Explosive rockets | Round 5 |
| **M20 Heavy Launcher** | 75 | 0.8 / s | 2 | 2.8 s | Huge blast radius | Round 8 |

## The horde

| Slime | Behaviour | Health | First seen |
|---|---|---:|:---:|
| **Slime** | Chases you down | 30 | Round 1 |
| **Swift Slime** | Fast and fragile | 18 | Round 3 |
| **Brute Slime** | Big, slow, hits hard | 140 | Round 4 |
| **Spitter Slime** | Keeps its distance and lobs acid that leads your movement | 22 | Round 5 |
| **Splitter Slime** | Bursts into fast Splitlings on death | 80 | Round 6 |
| **Charger Slime** | Telegraphs with a **!**, then dashes in a straight line | 45 | Round 7 |
| 👑 **Slime King** | Boss — arrives halfway through every 5th round | 650 | Round 5 |

Health values are base values; every round multiplies enemy health, speed and damage.

## Upgrades

28 upgrades across three rarities. Most stack; some have a cap.

<details>
<summary><b>Show all upgrades</b></summary>

| Upgrade | Rarity | Effect | Max |
|---|---|---|:---:|
| Hollow Points | Common | +20% damage | ∞ |
| Hair Trigger | Common | +18% fire rate | ∞ |
| Extended Mag | Common | +35% magazine size | ∞ |
| Speed Loader | Common | −20% reload time | ∞ |
| High Velocity | Common | +30% projectile speed, +8% damage | ∞ |
| Vitality | Common | +25 max health, heals 25 | ∞ |
| Heavy Rounds | Common | +60% knockback, +6% damage | 3 |
| Steady Aim | Common | −40% bullet spread, +10% projectile speed | 3 |
| Thorns | Common | When hit, blast nearby enemies for 30 damage | 3 |
| Adrenaline | Common | −25% dash cooldown | 3 |
| Magnet | Common | +50% pickup radius | 4 |
| Light Boots | Common | +12% move speed | 5 |
| Field Medic | Rare | Fully heal, +10 max health | ∞ |
| Bloodthirst | Rare | Heal 1 HP per kill | 3 |
| Incendiary Rounds | Rare | Hits ignite enemies for 25% of hit damage per second | 3 |
| Ricochet | Rare | Bullets bounce to +1 nearby enemy after their last hit | 3 |
| Shockwave Dash | Rare | Dashing ends in a 30-damage shockwave | 3 |
| Combat Drone | Rare | +1 drone that shoots the nearest slime | 3 |
| AP Rounds | Rare | Shots pierce +1 more enemy | 4 |
| Big Boom | Rare | +35% explosion radius, +10% damage | 4 |
| Guardian Orb | Rare | +1 orb circles you, shredding slimes it touches | 4 |
| Deadeye | Rare | +8% crit chance (crits deal 2× damage) | 6 |
| Last Stand | Epic | Below 30% health: +50% damage and fire rate | 1 |
| Second Chance | Epic | Once per run, revive at 50% health | 1 |
| Glass Cannon | Epic | +40% damage, −20 max health | 2 |
| Chain Lightning | Epic | Crits arc to +2 nearby enemies for 50% damage, +3% crit | 3 |
| Split Shot | Epic | +1 projectile per shot, −12% damage | 4 |
| Thunder Rod | Epic | Sky lightning strikes +1 slime every 2 seconds | 5 |

</details>

## Controls

| Action | Keyboard & mouse |
|---|---|
| Move | `W` `A` `S` `D` |
| Aim | Mouse |
| Shoot | Left mouse button (hold) |
| Reload | `R` |
| Dash | `Shift` |
| Build inspector | `Tab` or `I` |
| Pick upgrade | Click a card or press `1` / `2` / `3` |
| Pause | `Esc` |

Movement also works with a gamepad's D-pad and left stick.

## Getting started

### Requirements
- [Godot Engine **4.7**](https://godotengine.org/download) (standard build — no C#/.NET needed)
- A GPU with Direct3D 12 or Vulkan support (Forward+ renderer)

### Run from source
```bash
git clone https://github.com/AmitShok/Slime-Out.git
```
1. Open Godot 4.7 and **Import** the cloned folder's `project.godot`.
2. Let the first import finish (it generates the `.godot/` cache).
3. Press **F5** to play — the game starts on the main menu.

### Build a standalone game
1. In Godot, open **Editor → Manage Export Templates** and install the 4.7 templates.
2. **Project → Export → Add… → Windows Desktop**, then **Export Project**.

## Saves & settings

Everything is stored in Godot's user folder — on Windows:
`%APPDATA%\Godot\app_userdata\Slime-Out\`

| File | Contents |
|---|---|
| `run.json` | The in-progress run (autosaved every 10 s, at round milestones, after each pick and on quit). Deleted when the run ends. |
| `save.cfg` | Records — best round reached. |
| `settings.cfg` | Audio, video and crosshair options. |

Dying ends a run for good — it's a roguelite.

## Project structure

```
├── scenes/            Game, main menu, player, enemy, weapon, UI and arena scenes
├── scripts/
│   ├── autoload/      Events bus, Settings, Sound director, SceneFader
│   ├── data/          Resource classes: WeaponData, UpgradeData, EnemyData, Stats
│   ├── fx/            Debris, decals, shockwaves, lightning, damage numbers
│   ├── ui/            HUD, menus, upgrade cards, build inspector, crosshair
│   ├── game.gd        Round loop, level-ups and run save/restore
│   ├── wave_manager.gd  Spawning and difficulty scaling (all tunable in the inspector)
│   └── player_stats.gd  Weapon-agnostic upgrade stacking
├── resources/         Weapon, enemy and upgrade definitions (.tres), themes, tilesets
├── shaders/           CRT, iris wipe, wind sway, hit flash, screen overlay
├── assets/            Sprites, tiles, audio (third-party packs + floor38/ originals)
├── art_src/           Aseprite sources and the generator scripts below
└── docs/              README images
```

**Design notes**
- Upgrades are data: each `UpgradeData` holds `StatModifier`s (flat or percent). Final stat = `(base + Σflat) × (1 + Σpercent)`, so swapping weapons just changes the base.
- Gameplay systems talk through the `Events` autoload (screen shake, hits, kills, bosses) instead of hard references.
- Big hordes stay fast with a spatial hash for enemy separation and caps on decals, casings and damage numbers.

## Content pipeline

Original art and audio are generated from source scripts so they can be tweaked and rebuilt:

| Script | Produces |
|---|---|
| `art_src/tools/build_player.lua` | Hero sprite sheet |
| `art_src/tools/build_fx_enemies.lua`, `build_fx_small.lua`, `build_juice.lua` | Slime variants, explosions, sparks, gems, pickups, orbs, drones |
| `art_src/tools/build_ui_icons.lua`, `build_reticle.lua`, `build_logo.lua` | Upgrade icons, crosshair parts, title logo |
| `art_src/tools/build_arena.lua` | Arena decorations and fireflies |
| `art_src/tools/build_arena_scenes.gd` | Bakes the arena scenes (tiles, forest, fence, obstacles) |
| `art_src/tools/build_sfx.gd` | Gunshots, reloads, casings, drone shots |
| `art_src/tools/build_music.gd` | The "Slime Rush" gameplay track |

```bash
# Aseprite art (run from the project folder)
Aseprite.exe -b --script-param root=<project path> --script art_src/tools/build_logo.lua
# Godot generators
godot --headless --path . --script art_src/tools/build_sfx.gd
```

## Credits

**Slime-Out** is made by **Floor 38 Studio** — game design, code, original pixel art, sound design and music.

Third-party assets:
- **Mystic Woods** tileset, trees and slime base sprites — by [Game Endeavor](https://game-endeavor.itch.io/mystic-woods)
- **Guns V1.01** weapon sprites and animations
- **Ninja Adventure Asset Pack** sound effects, jingles, ambience and menu music — by [Pixel-boy & AAA](https://pixel-boy.itch.io/ninja-adventure-asset-pack) (CC0)
- **160+ Cursors Crosshairs Pack**
- **Agent Mike** bullet UI icon
- Built with the [Godot Engine](https://godotengine.org)

Design inspiration: *Vampire Survivors*, *Enter the Gungeon*, *Nuclear Throne* and *Brotato*.

## License

No open-source license has been chosen yet, so all rights to the original code and art are reserved by **Floor 38 Studio**. Third-party assets remain under their respective creators' licenses.
