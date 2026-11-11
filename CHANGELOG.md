# Changelog

## 2.0 - premium upgrade
**Physics and feel**
- Ball simulation rewritten: 240 Hz, drag with Cd 0.45, Magnus lift from spin ratio, spin decay, speed-dependent restitution, spin-aware friction on every surface.
- Swept-sphere collision against the table slab, net, posts and floor with true contact normals: edge balls and net cords come from geometry, nothing tunnels at 35 m/s.
- Bat contact is now an impulse model (bat velocity, face angle, rubber speed/grip, sweet spot). Player and bots both solve for a swing; a misread spin goes wrong physically.
- Named strokes from the swipe: touch, push, chop, drive, loop, smash.
- Render interpolation, finger prediction, hit-stop, camera shake, scaled haptics, speed-based trail, rotating ball logo.
- Realistic spin magnitudes (serves up to ~95 rev/s).
- Physics tests added to CI (drop height, topspin dip, flat bat vs spin, sidespin kick, no tunnelling).

**Visuals**
- Procedural PBR textures (paint grain, wood, pimpled rubber, net mesh), smooth high-segment geometry, five-layer bats, full table undercarriage and net posts.
- Jointed characters with per-stroke swing poses, footwork and serve toss.
- Per-arena light rigs, depth fog, bloom, ACES tonemapping, reflection probe, soft shadows, animated crowd that reacts to points.
- Quality presets Low / Medium / High / Ultra with auto-detect and automatic render-scale fallback. High and Ultra render at native resolution with 4x MSAA.
- Orbiting slow-motion replay camera.

**Menus, HUD, sound**
- Montserrat design system, glass cards, one accent colour, press and transition animation, animated stat bars and count-ups.
- Live blurred 3D backdrop behind the menus; rotating 3D preview of bats, balls and tables.
- Broadcast scoreboard with serve indicator; notch-safe layout.
- Layered ball sounds driven by speed, spin and surface; applause, rally tension bed, UI sound set, richer music loop.

**Build**
- One fixed debug keystore in `ci/debug.keystore` (the same key earlier builds used), so new APKs install over old ones and keep progress.

## 1.0
- First playable release.
