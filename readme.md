# ParkBench TD

A VR tower defense game played from a park bench. Built with Godot 4.x and OpenXR.

## Concept

You sit at a park bench with a tabletop battlefield in front of you. Reach over to the shop on the bench, grab towers, and place them to defend against waves of enemies marching across the map.

## Gameplay

- **Setting**: Seated at a park bench, looking down at a table with the TD map
- **Core loop**: Enemies spawn → place towers from shop → towers auto-attack → earn currency → buy more towers → survive all waves
- **Win condition**: Survive all enemy waves
- **Lose condition**: Enemies reach the end of the path too many times (lives depleted)

## Scope (v1)

- One map, one enemy path
- 2-3 tower types
- One enemy type (more if time allows)
- Single currency system
- Simple lives/health counter
- Basic win/lose states

## Tech Stack

- **Engine**: Godot 4.x
- **VR**: Godot XR Tools addon (OpenXR) for grabbing, placing, locomotion
- **Version Control**: Git
- **Assets**: Downloaded/free assets (TBD)

## Requirements

- VR headset with OpenXR support
- Tracked controllers (for grabbing/placing towers)

## Further details

Found here: [idea.md](idea.md)