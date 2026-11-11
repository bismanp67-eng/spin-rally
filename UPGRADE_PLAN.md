# Upgrade plan (audit of v1.0)

Ranked by how much each weakness hurts the game.

| # | Area | Weakness in v1.0 | Fix |
|---|------|------------------|-----|
| 1 | Physics | Bat contact is faked: the game picks an outgoing velocity and spin directly. Incoming spin only adds a hand-tuned error. | Real impulse model (bat velocity, face angle, restitution, rubber grip, sweet spot). Player and bots solve for a *swing*; misread spin then goes wrong physically. |
| 2 | Physics | 120 Hz, constant Magnus factor, spin values ~4x too low, constant restitution, net/table tested only by plane crossing. | 240 Hz, Cd 0.45 drag, Magnus with spin-ratio lift coefficient, speed-dependent restitution, swept-sphere collision against table slab, net, posts and floor with true contact normals (edge balls, net cords). |
| 3 | Feel | No hit-stop, no camera shake, fixed haptic pulse, ball drawn at tick positions (judder at 60 fps), bat lags the finger. | Render interpolation, finger prediction, hit-stop and shake scaled by hit strength, scaled haptics, named strokes (touch, push, chop, block, drive, loop, smash). |
| 4 | Visuals | Flat untextured materials, faceted low-segment meshes, render scale below 1, no fog or bloom. | Procedural PBR textures (grain, wood, pimpled rubber, net mesh), high-segment geometry, layered bat, four quality presets with auto-detect, native resolution on High/Ultra. |
| 5 | Visuals | Characters are a capsule with one rigid arm swing for every shot. | Jointed arm, body lean, footwork, and per-stroke swing poses. |
| 6 | Visuals | Arenas share one lighting setup; crowd is static. | Per-arena light rigs, depth fog, animated crowd shader that reacts to points. |
| 7 | Menus | Default engine font, flat list of buttons on a plain colour, nothing animates. | Montserrat design system, live 3D orbiting background, glass cards, transitions, press feedback, animated bars and count-ups, 3D equipment preview. |
| 8 | HUD | Centre-text score, no serve indicator, bare pause menu. | Broadcast scoreboard with games, points and serve dot; notch-safe layout; cleaner pause. |
| 9 | Audio | One thin sine "tick" per surface, one noise burst for the crowd, simple music. | Layered ball sounds driven by speed/spin/surface, applause and gasp layers, rally-tension bed, UI sound set, richer music loop. |
| 10 | Build | Signing key came from the CI image, so a changed image would break updates-in-place. | One fixed debug keystore committed to the repo (personal use only). |

Not planned (see NOTES.md): online play, photo-real characters, geometric finger-driven bat collision.
