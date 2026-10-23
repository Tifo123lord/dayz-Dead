# DEADLAND: AFTER ZERO — Minimal Demo

A single playable screen made with plain Flutter (no game engine): a survivor walks across a ruined pixel-art city.

## Contents
| File | Purpose |
|---|---|
| `lib/main.dart` | Demo screen: Ticker game loop, input, sprite animation (CustomPainter), footsteps |
| `assets/images/background.png` | Environment (1360×768, drawn with `BoxFit.cover`) |
| `assets/images/survivor_walk.png` | 8-frame walk-cycle sprite sheet (1344×300, transparent PNG, 168 px per frame) |
| `assets/images/survivor_poses.png` | 4 pose cells (260×300): aim, crouch-aim, crouch-low, jump – all holding the AK-47 |
| `assets/images/ak47.png` | AK-47 sprite (carried while walking + HUD icon) |
| `assets/audio/ak47_shot.wav` | Single AK-47 gunshot (ElevenLabs SFX, trimmed/normalized) |
| `assets/audio/ak47_reload.wav` | AK-47 magazine reload |
| `lib/zombies.dart` | Zombie types, AI, waves, damage, gore/spores, positional zombie audio |
| `assets/images/zombie_walk.png` | Walker zombie 8-frame walk sheet (1600×300, 200 px cells) |
| `assets/images/mushroom_walk.png` | Sporeback (mushroom-head) zombie 8-frame walk sheet |
| `assets/audio/zombie_groan.mp3`, `zombie_attack.mp3`, `zombie_death.mp3` | Walker voice |
| `assets/audio/mushroom_groan.mp3`, `mushroom_death.mp3` | Sporeback voice |
| `assets/audio/flesh_hit.mp3` | Bullet impact on flesh |
| `assets/audio/footstep.wav` | One footstep, generated with ElevenLabs Sound Effects during development and trimmed to a single step |

No API keys are stored in the project. The audio file is bundled with the app.

## Controls
| Action | Touch | Keyboard |
|---|---|---|
| Walk | ◀ / ▶ | ← → / A D |
| Jump | JUMP | ↑ / W / Space |
| Crouch | CROUCH (toggle) | ↓ / S / C / Ctrl (hold) |
| Fire (full-auto, hold) | FIRE | F / J / Enter |
| Reload | ⟳ | R |
| Switch weapon (AK-47 ⇄ Desert Eagle) | GUN / tap the weapon slot | Q / Tab / 1 / 2 |
| Use passage / search container / water pump | context button (appears when near) | E |
| Eat / drink / bandage / medkit / antibiotics | backpack bar (bottom centre) | 3 / 4 / 5 / 6 / 7 |

AK-47: 600 RPM, 30-round magazine + 120 reserve, 2 s reload (auto-reload on empty trigger pull). Crouching halves spread; spread grows during sustained fire. Each shot = muzzle flash, tracer, ejected brass, smoke, recoil and slight screen shake; 7 audio voices allow overlapping full-auto shots. Three practice targets (5 hits each) fall and reset.

## Run
```bash
flutter pub get
flutter analyze
flutter run                 # device/emulator
flutter run -d chrome       # web preview
```

## Build the APK
```bash
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```
The app runs in landscape only. Package name: `com.deadlandafterzero.game`.

## Tuning
In `lib/main.dart`: `_groundY` (road line in the background's pixel coordinates), `_playerH`, `_speed`, `_walkFps`. Footstep volume: `_steps.setVolume(0.55)`.

## Zombies
| Type | HP | Speed | Damage | Special |
|---|---|---|---|---|
| WALKER | 100 | fast shamble | 12 | Headshot ×2.5, staggers on hit |
| SPOREBACK (mushroom head) | 240 | slow | 18 | Headshot ×2.0, slam releases spore puff, bursts into a toxic spore cloud on death |

Each zombie shows a name plate + HP bar (trailing damage, 25-HP ticks, colour by health). Waves grow in size; drops: ammo boxes and medkits. Zombie sounds are panned/attenuated by position and pitch-varied; distant horde groans play randomly.

## Areas
| Area | Passage | Sound |
|---|---|---|
| RUINED CITY (`background.png`) | Metro stairwell with a red **M** sign at the right end of the street | Wind/ash, distant horde, dry footsteps |
| RAVENCROFT METRO (`metro_bg.png`) | Staircase on the left, back up to the street | Echoing footsteps, gunshot reverb tails, echoing zombie groans, buzzing/flickering lights, water drips, groans from the tunnel |

The trip fades to black with stair footsteps. Zombies still alive follow you into the new area, and the wave continues.

## Desert Eagle .50 AE
Semi-auto, 7-round magazine + 35 reserve, 92 damage per round (headshots x2-2.5), 2.2 s reload. Each round passes through the first zombie (65% damage carries to the next). Heavy recoil, muzzle climb, screen shake, a big muzzle flash and large .50 casings that clink on the floor.

## Survival world (v1.2)
One continuous, auto-saved world (no chapters, no ending). Main menu: **Continue**, **New survivor** (difficulty + start area), **Characters**, Shop, Settings.

* **Needs:** hunger and thirst drain over time (faster while walking / infected); at 0 they cost health.
* **Injuries:** zombie hits can cause bleeding (1-3 levels, bandage / medkit), a leg injury (slower, lower jumps) and Sporeback infection (antibiotics). Untreated infection above 35% keeps spreading.
* **Scavenging:** 9 containers (car trunks, bus, train car, suitcases, cabin, backpack...) refill after a while; the forest water pump gives unlimited untreated water.
* **Day / night:** one day = 6 real minutes; nights are darker with bigger hordes.
* **Areas:** Ruined City <-> Ravencroft Metro, Ruined City <-> Blackwood Forest (rain, fog, lightning and thunder).
* **Passing out:** you wake up 3 hours later at the safe spot of the area and lose half of your supplies and spare ammo; upgrades, coins, skins and the world are kept.
* **Characters:** Arash (fast, quick reload) and Donald (+40 HP, 10% armour, less recoil/spread, heavy).
