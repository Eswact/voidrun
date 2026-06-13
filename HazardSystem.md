# Hazard System — Technical Design

## Core Philosophy
Each hazard is a self-contained scene. The HazardDirector decides when to spawn what.
Adding a new hazard = create scene + register in Director. Nothing else changes.

---

## HazardDirector (scripts/HazardDirector.gd)

Central controller. Runs a timeline based on `survival_time` (seconds).

```
survival_time → lookup timeline → spawn/activate hazards
```

### Timeline Structure
```gdscript
var timeline = [
    { "at": 0,   "spawn": "projectile_stream",  "params": { "rate": 1.5 } },
    { "at": 30,  "spawn": "wall_disc",           "params": { "count": 1 } },
    { "at": 30,  "spawn": "projectile_stream",   "params": { "rate": 2.5 } },
    { "at": 60,  "spawn": "explosive_projectile","params": { "rate": 1.0 } },
    { "at": 90,  "spawn": "ground_crack",        "params": { "size": "small" } },
    # add new entries here — Director handles the rest
]
```

### Responsibilities
- Track survival_time
- Fire timeline events at correct times
- Manage active hazard instances (enable/disable)
- Emit signal `difficulty_changed(phase: int)` for visual/audio escalation

---

## Hazard Base Class (scripts/hazards/BaseHazard.gd)

All hazards extend this.

```gdscript
class_name BaseHazard extends Node2D

signal hazard_hit_player

func activate(params: Dictionary) -> void:
    pass  # override in each hazard

func deactivate() -> void:
    pass  # override in each hazard
```

---

## Hazard Types

### 1. ProjectileStream
**File:** scenes/hazards/ProjectileStream.tscn  
**How:** Spawns projectiles from random arena edges at regular intervals.  
**Params:** `rate` (per second), `speed`, `size`  
**Scales:** rate and speed increase over time via Director

### 2. WallDisc
**File:** scenes/hazards/WallDisc.tscn  
**How:** A spinning disc that travels along the arena walls (top → right → bottom → left).  
**Params:** `count`, `travel_speed`, `spin_speed`  
**Scales:** count increases, travel_speed increases

### 3. ExplosiveProjectile
**File:** scenes/hazards/ExplosiveProjectile.tscn  
**How:** Projectile flies in, stops briefly, explodes into radial spread.  
**Params:** `rate`, `spread_count`, `warn_duration`  
**Scales:** rate and spread_count increase

### 4. GroundCrack
**File:** scenes/hazards/GroundCrack.tscn  
**How:** A zone appears on the floor with a warning flash, then becomes lethal.  
**Params:** `size`, `warn_duration`, `active_duration`  
**Scales:** more zones active simultaneously, shorter warn_duration

### 5. (Next slot — reserved)
Follow the same pattern to add more.

---

## Adding a New Hazard — Checklist

1. Create scene: `scenes/hazards/NewHazard.tscn`
2. Attach script that extends `BaseHazard`
3. Implement `activate(params)` and `deactivate()`
4. Connect `hazard_hit_player` signal to Director
5. Add entry to Director's `timeline` array
6. Done

---

## Object Pooling

Director maintains a pool per hazard type.  
Hazards are not freed — they are deactivated and reused.

```gdscript
# Director internals (simplified)
var pools = {
    "projectile_stream": [],
    "wall_disc": [],
    ...
}

func get_hazard(type: String) -> BaseHazard:
    for h in pools[type]:
        if not h.active:
            return h
    # if none free, instance new one and add to pool
    var h = preload("res://scenes/hazards/...").instantiate()
    pools[type].append(h)
    return h
```

---

## Signals Flow

```
HazardDirector
    → hazard_hit_player   →  GameManager (trigger death)
    → difficulty_changed  →  AudioManager (music layer)
                          →  ArenaManager (visual corruption)
```

---

## Files To Create

```
scripts/
├── HazardDirector.gd
└── hazards/
    ├── BaseHazard.gd
    ├── ProjectileStream.gd
    ├── WallDisc.gd
    ├── ExplosiveProjectile.gd
    └── GroundCrack.gd

scenes/hazards/
    ├── ProjectileStream.tscn
    ├── WallDisc.tscn
    ├── ExplosiveProjectile.tscn
    └── GroundCrack.tscn
```