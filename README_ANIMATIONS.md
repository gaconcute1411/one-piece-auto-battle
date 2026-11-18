# Animation Library and Practice Mode

The project now uses the supplied idle animations for all 24 characters.

## Idle animations

- `animations/<character>/idle_loop/f01.png` through `f07.png` are available for each roster character (168 frames total).
- Every SpriteFrames resource exposes both `idle_loop` and `battle_loop`, each looping at 6 frames per second. The latter keeps existing battle and UI callers compatible.
- Transparent borders are cropped per character using one shared rectangle across all 7 frames. This keeps every pixel of the character artwork while reducing idle texture pixel memory by roughly 74–77%. Per-character foot pivots keep the feet steady; nearest-neighbor filtering preserves crisp edges.
- The eight original character libraries retain their `s1`, `s2`, and `ult` animation clips.

## Practice mode

Open **Huấn luyện** from the lobby, select 1–6 different characters, then enter the arena. Six high-health wooden dummies do not attack. Their health bars visibly decrease and refill when depleted so attacks and damage effects can be observed continuously. Use the speed control or end the session from the top-right controls.

## Importing

Open `project.godot` in Godot 4.7 or newer and let the editor finish importing the PNG assets before running the project.
