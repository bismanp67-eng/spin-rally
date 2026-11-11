# Notes (decisions made unattended)
- Portrait orientation, camera behind player (best for one-thumb swipes).
- Godot 4.7.2 (latest stable), CI image barichello/godot-ci:4.7.2.
- All visuals/UI/sounds are built in code; content lives in data/*.json.
- Bots: 15 named characters (spec asked for 10) so a 16-player tournament bracket has unique opponents.
- Players do not swap ends between games (camera stays behind you); server alternation follows ITTF.
- Volley fault applies only while the ball is over your half of the table; early swipes within ~0.14 s of the bounce are treated as half-volleys.
- Player accuracy depends on timing (hit near the top of the bounce = PERFECT), swipe power, incoming pace, and choosing the right stroke for the incoming spin (push backspin or loop it hard; do not push topspin).
- Ghost serve nearly stops on the second bounce rather than rolling back to the net (friction model limit); the challenge was defined accordingly.
- Tournament matches between bots are resolved by rating, not simulated ball by ball.
- Balls and arenas are cosmetic; tables change bounce/friction slightly (glass and ice are slicker, concrete is deader).
- Built and tested headless plus software-rendered screenshots only; it has never run on a physical phone, so touch feel and frame rate are unverified.

## v2.0 decisions
- Signing: CI copied the keystore earlier builds were signed with into `ci/debug.keystore`; it is a debug key with the standard password, for personal use only.
- The finger does not drive a geometric bat collider. A swipe inside the hitting window triggers a swing; the contact itself is the physical impulse model. Swept collision covers table, net, posts and floor.
- Serves and the ball machine still set launch velocity and spin directly from data; only rally strokes go through the bat impulse model.
- Sidespin is given a tilted axis (some corkscrew) so it kicks sideways off the bounce; a pure vertical axis does not.
- The Mobile renderer has no screen-space ambient occlusion, so contact shadows are soft blobs under the table, players and ball.
- Texture size follows quality: 2048 px on Ultra, 1024 on High, 512 on Medium, flat colours on Low.
- The ball's visible rotation is slowed to a tenth of the real rate so the logo is readable instead of strobing.
- Old saves: a quality setting left at the old default (Medium) is switched to auto-detect; an explicit Low or High choice is kept.
- Spin misreads are scaled (READ_K in `scripts/core/shot.gd`) because the true physical sensitivity made flat drives unplayable.
- Screenshots were reviewed with software Vulkan on the Mobile renderer; frame rate on a phone is still unmeasured, so auto quality lowers the render scale if fps sags.
