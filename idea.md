# ParkBench TD

## IDEA

A VR tower defense game played from a park bench. The player sits at a
table with a small battlefield map laid out in front of them, and
defends it by placing towers as waves of enemies march across.

## SETTING

- Player is seated at a park bench, looking down at a table.
- The tower defense map sits on the tabletop.
- A shop is placed nearby on the bench, holding the towers
  available to buy and upgrade.

## CORE GAMEPLAY LOOP

1. Enemies spawn and walk along a fixed path across the table.
2. Player reaches over to the shop, grabs a tower, and places it on an
   open tile near the path.
3. Towers automatically attack enemies that pass within range.
4. Killing enemies earns currency.
5. Currency is spent on more towers (or better ones or upgrades) from the shop.
6. Player loses if enemies reach the end of the path too many times.
7. Player wins by surviving all the waves.

## FIRST VERSION SCOPE

- One map, one enemy path.
- 2-3 tower types.
- One enemy type (add more later if time allows).
- One currency.
- Simple win/lose condition (base health or lives counter).

## PRELIMINARY REQUIREMENTS

- VR headset with OpenXR support, tracked controllers for grabbing.
- Player can grab a tower from the shop and place it on a valid tile.
- Towers detect enemies in range and attack automatically.
- Enemies follow a fixed path from start to end point.
- Currency is tracked and earned from enemy kills.
- Shop lets the player spend currency on towers (and upgrades, if kept in scope).
- UI shows currency, remaining lives/base health, and wave count.
- Game detects and displays win (all waves survived) and lose (lives reach 0) states.

## TOOLS & TECHNOLOGIES

- Engine: Godot 4.x
- VR integration: Godot XR Tools addon (OpenXR) for grabbing, placing, and locomotion
- Headset: TBD
- Version control: Git
- 3D assets: TBD (Downloaded assets mostly)

## NOT DOING

- Multiple maps
- Multiple currencies
- Complex enemy AI