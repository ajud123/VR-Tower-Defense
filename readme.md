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

## Project layout

- `main_menu/` – title screen (the startup scene) with a PLAY button
- `gameplay/` – the park scene: picnic table, board (`board.gd`), shop, towers, enemies, waves, cards and the vending machine
- `player/` – shared player rig: VR headset + hands, or a desktop camera when no headset is running
- `interactables/` – push button, pull lever, and the ray used to aim at them

In VR, press a button by poking it with your hand or by pointing the laser at it
and pulling the trigger.

The board builds its tiles, enemy path, spawn portal and base from the values in
the inspector (grid size, tile size, path corners), and rebuilds live in the
editor.

## How a game plays (current build)

- 10 waves come down the path, each bigger and tougher. Tanks (big purple
  blobs: slow, lots of HP, more gold) join from wave 2.
- Each enemy that reaches the castle costs a life. At 0 lives it's game over;
  clearing all 10 waves wins. Use RESTART or MENU on the table afterwards.
- Killing enemies earns gold, and clearing a wave pays a bonus (30 + 10 per wave).
  Gold buys towers from the shop tray (hover one to see its stats):
  Archer (60, fast single shots), Cannon (100, slow splash) and Mage (140, long range, 1.5x damage vs tanks).
- Towers can only go on free grass tiles, not on the path or on another tower.

**Cards (upgrades)**
- The CARD-O-MATIC vending machine behind the bench opens at wave 3. Pull its
  lever (grab and pull down in VR, click on desktop) to buy a random card you
  don't own yet: 250 gold, +75 for each card after that.
- Bought cards pop out of the machine onto the ground. Pick them up and put
  them in one of the 3 gold slots on the card station (left of the table) to
  activate them, in its storage mat, or down anywhere (they're physical).
  - **VR:** squeeze the grip on a card (touch or laser), let go over a slot,
    the storage mat, or anywhere else to drop it.
  - **Desktop:** click a card to pick it up (shown bottom right), then click a
    slot, the storage mat, another card (swaps), or anywhere to drop it.
    Right click drops it in front of you.
- To add a card, drop a new `.tres` (script `gameplay/cards/card.gd`) into
  `gameplay/cards/pool/`. Effects are stat keys like `mage.fire_rate` or
  `enemy.health`; `card.gd` lists them all.

**Building a tower**
- **VR:** squeeze the grip on a shop tower (touch it, or point the laser at it),
  carry it over the board and let go. The tile under it lights up green
  (OK) or red (blocked/too expensive). Let go anywhere else to put it back.
  You can also point and pull the trigger, like on desktop.
- **Desktop:** click a shop tower, then click a tile. Right click (or clicking the
  same shop tower again) cancels.

Tower stats live on the tower scenes in `gameplay/towers/`, enemy stats on
`gameplay/enemies/blob.tscn` / `tank.tscn`, wave sizes and scaling in
`gameplay/wave_spawner.gd`, starting lives/gold on the `Game` node, and card
prices on the `VendingMachine` node.

## Desktop testing

Run the project without an initialized VR headset to use the desktop test camera.
To force desktop mode even with VR connected, add `--desktop` to Godot's
**Project > Project Settings > Editor > Run > Main Run Args** (enable Advanced
Settings if needed), or launch from the command line with
`godot --path . -- --desktop`.

- **WASD**: move horizontally
- **Q / E**: move down / up
- **Shift**: move faster
- **Mouse**: look around
- **Left click**: press the button / shop tower / tile under the crosshair
- **Right click**: cancel tower selection
- **Escape**: release the cursor and pause movement
- **Left click**: capture the cursor again

This is a free-moving camera for development; it can pass through objects.

## Further details

Found here: [idea.md](idea.md)
