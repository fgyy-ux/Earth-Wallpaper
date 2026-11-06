# Earth Wallpaper — Godot 3.5.3 Mono

A complete portrait 3D scene: a compact upper-left Earth, a quiet star background, clockwise Y-axis rotation, and tap-to-expand/tap-to-minimize animations. The expanded view fills much of the screen height and crops the Earth at the left edge so only its right side is visible.

## Open and run

1. Open **Godot 3.5.3-stable Mono** (the C# edition).
2. In the Project Manager, choose **Import** and select `project.godot` in this folder.
3. Let the editor import the Earth and star textures.
4. Click **Build** to compile the C# solution. Install a .NET SDK / .NET Framework 4.7.2 targeting pack if Godot reports missing build tools.
5. Press **F6** to run the scene or **F5** to run the project.
6. Click or tap anywhere in the scene once to enlarge it. Tap again after the animation finishes to minimize it.

Short taps on the globe or empty background trigger on release. Swipes, long presses, additional fingers, and presses during a transition are ignored. Expansion briefly moves right with a gentle extra clockwise turn, then settles left into the cropped view. Idle rotation continues in either state.

The compact Earth starts with side lighting. Expansion reveals a soft eclipse ring and a diamond of sunlight at the limb, followed by a gradual crossing and fade toward the right. The disc has a fixed radius of 0.12 units, twice its original display size, and the reveal lasts 7.2 seconds. The Earth-centered ring never expands into a giant flare. The visible Sun uses a compressed lateral sky path with actual orbital depth: after the right exit it passes behind the camera, and its directional sunlight turns Earth's day side toward the viewer. Minimizing smoothly restores the compact, side-lit view, including during the reveal.

NASA Black Marble city lights appear as soft golden points on the night side and fade smoothly through twilight. A narrow anamorphic flare crosses the sky during diamond contact. Both effects use the current Sun direction and leave physical sunlight energy unchanged.

## Included files

- `scenes/EarthWallpaper.tscn`: Earth, distant Sun, fixed portrait camera, directional sunlight, and separate Earth/Sun Tweens.
- `scripts/EarthWallpaper.cs`: Godot 3 C# interaction and animation.
- `shaders/`: day/night Earth surface, small solar disc/glow, eclipse ring, and focused contact flare.
- `assets/earth.png`: NASA Earth texture; see third-party notices.
- `assets/earth_night.jpg`: NASA Black Marble city-light map, imported at mobile resolution.
- `assets/stars.svg`: locally authored lightweight star background.
- `export_presets.cfg`: Android preview preset.
- `docs/SETUP.md`: complete settings, signal guide, and Android instructions.

## Scope

The Android preset exports a fullscreen **app preview**. Installing this as an Android home-screen live wallpaper still needs a native `WallpaperService` host, rendering integration, touch forwarding, and visibility handling. These are not supplied by this Godot scene or ordinary APK export. See `docs/SETUP.md`.

No clock/widgets are drawn by the project: the layout reserves the right side for a launcher's widgets.
