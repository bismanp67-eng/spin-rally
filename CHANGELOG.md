# Changelog

## 2.2.3 - crash fix
- Fixed the crash during play: generated sounds could be read past their end by the audio mixer on Android. Every sound now has a guard tail.

## 2.2 - stability
- Much lower memory and GPU load on Medium and High; 2048 px textures and the reflection probe are Ultra only; 3D resolution is capped on very dense screens.
- Auto-detect is more conservative, and the game lowers graphics by itself after an unexpected close.

## 2.1 - real bat
- The bat is a real object: it follows the finger every physics step and the ball is hit only when the swept ball meets the moving blade. Contact point (sweet spot or edge) feeds the impulse model; edge hits are weaker and deflect.
- Assist setting: Off (pure physics, true blade size), Light (default), Strong. Holding the bat still in the ball's path now blocks.
- Bots use the same blade geometry and sweep test.
- Serves: real toss, then the bat strikes the falling ball through the impulse model; each serve is a bat path, and spin comes out of the contact. Bots serve the same way.
- Ball machine: wheel-style speed and spin.
- Faked ambient occlusion (crease strips, contact blobs), softer shadows, lighting pass over all ten arenas, brighter menu backdrop.
- 2048 px table normal map, bat and ball textures on High.
- Slow-motion replays for great points (long rallies, 25 m/s+ shots, edge and net-cord points, deep retrieves), at most once every 3 points.
- Opponents react to each point (cheer or slump).
- New tests: bat reach, 35 m/s swing tunnelling, edge contact, every serve type.

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
