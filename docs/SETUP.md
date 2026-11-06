# Godot 3.5.3 Mono setup

Use Godot **3.5.3-stable Mono**, not Godot 4. Godot 3 names its 3D nodes Spatial, MeshInstance, Camera, Area, and CollisionShape.

## Scene hierarchy

```text
EarthWallpaper (Spatial) [scripts/EarthWallpaper.cs]
├── Background (CanvasLayer)
│   └── Stars (TextureRect, Mouse Filter Ignore)
├── Camera
├── EarthRoot (Spatial)
│   ├── Spin (Spatial)
│   │   └── EarthMesh (MeshInstance)
│   └── TapArea (Area)
│       └── CollisionShape
├── Tween
├── Sun (Spatial)
│   ├── Core (MeshInstance)
│   ├── Corona (MeshInstance)
│   ├── Flare (MeshInstance)
│   └── SunLight (DirectionalLight)
├── SunTween
├── EclipseRing (MeshInstance)
└── WorldEnvironment
```

EarthRoot's translation and uniform scale are animated together. Spin only rotates the mesh. The spherical collision target follows the globe's position and size without requiring mesh collision.

## Portrait and camera

The project uses a 720 × 1280 base window, portrait orientation, stretch mode **2d**, stretch aspect **expand**, GLES2, and a 30 FPS cap.

Camera is at (0, 0, 8), with zero rotation, projection **Orthogonal**, keep aspect **Keep Width**, size 6, near 0.1, far 1200, and current enabled. The camera looks down -Z. The far plane includes the distant Sun when it is behind Earth. Neither the Sun's orbit nor Earth's approach changes the camera position, rotation, or projection.

At this camera size, visible horizontal world coordinates are -3 through +3. Default globe center is (-1.35, 1.15, 0), radius 0.65: approximately 28% of screen width and 39% of height at 9:16. Expanded center is (-4.25, 0, 0), radius 4.5. The center moves beyond the left edge, leaving only the globe's right side visible, centered vertically. Its right edge reaches approximately 54% of screen width, and the visible portion occupies about 80% of the portrait height.

Select EarthWallpaper in the Inspector to edit the exported positions, scales, rotation speed, and transition duration. Keep scales positive and uniform. Clockwise Y rotation means a negative angle viewed from above (+Y toward the origin).

## Touch and signals

1. Project Settings → Input Devices → Pointing: disable **Emulate Mouse From Touch** and **Emulate Touch From Mouse**. Native screen touch events and desktop mouse events are already handled separately.
2. `_UnhandledInput` captures the primary finger or left mouse button anywhere in the scene, including empty background.
3. No Area signal connection or Input Map action is needed. TapArea and its SphereShape remain in the hierarchy as an optional globe collision target.
4. A single tap toggles the view on release. It must stay within 24 logical viewport pixels and finish within 350 ms. Swipes, long presses, additional fingers, and presses during transitions are ignored.
5. Decorative Controls over the scene should use Mouse Filter **Ignore**. Interactive Controls consume their own input before the scene receives unhandled events.

Expansion takes 0.8 seconds (`ExpansionSeconds`), while minimization takes 0.5 seconds (`TransitionSeconds`). During expansion, the first 35% of the transition moves the globe slightly right with an additional 8-degree clockwise Y turn. It then eases left into the vertically centered cropped position. Scale animates throughout, and idle rotation continues without resetting. Minimization returns directly to the compact layout. The root Inspector exposes `ExpansionRightwardOffset` (default 0.45 units) and `ExpansionTurnDegrees` for tuning the gesture.

The Godot 3 Tween node calls `ApplyEarthTransition` through `InterpolateMethod`, with one progress track controlling both translation and uniform scale. Smoothstep easing joins the rightward and leftward legs with zero velocity at their meeting point. This avoids two delayed tweens competing to write the same position. Idle yaw and the approach's extra yaw are combined into a fresh unit rotation basis, preserving the model's initial orientation without accumulating scale or shear. The script is not an editor tool and does not animate geometry while editing.

## Mobile visuals

Earth's SphereMesh has radius 1, height 2, 24 radial segments, and 12 rings. The Sun uses a 32-segment/16-ring sphere and three quads for its local glow, eclipse ring, and contact flare. There is one dynamic DirectionalLight, no shadow maps, and no atmospheric/cloud meshes. Both day and night textures render at 1024 × 512 for mobile. The night source JPEG remains unmodified on disk; its import size limit is 1024 pixels, with filtering and mipmaps. Per-pixel shading is explicitly enabled on mobile so the terminator does not degrade into coarse vertex lighting.

## Sun reveal, orbit, and lighting

- The compact globe starts with the Sun to the right: a tilted terminator divides the visible disc into day and night. A tap begins the Earth approach and a separate 7.2-second Sun reveal. The solar direction travels behind Earth during the first 22%, holds until 40%, then moves right over 4.32 seconds (previously 2.88 seconds). The incoming display pass stays hidden. The disc fades in while occulted and peeks past the limb as a diamond, with a restrained local glow. The eclipse ring remains centered on Earth and fades once the disc clears the edge.
- Sun is a sibling of EarthRoot. Its orbit follows Earth's center with a fixed radius of **1,000 world units**, independent of Earth's rotation and animated scale. Once revealed, it continues at 8 degrees per second on an orbit tilted 15 degrees. The orbital plane uses the camera's axes, while positions are assigned in world coordinates.
- SunLight is a **DirectionalLight** child at the Sun's origin. `LookAt` aims its local -Z axis toward Earth's center. It is the only direct light and supplies parallel rays everywhere, with no point-light range or inverse-distance attenuation. Godot ignores a DirectionalLight's position when calculating illumination; its orientation defines the incoming rays. Moving it far away alone would not convert an OmniLight into sunlight. See [Godot 3.5 DirectionalLight](https://docs.godotengine.org/en/3.5/classes/class_directionallight.html).
- `earth_surface.shader` uses Lambert diffuse reflection and disables specular glare. Actual mesh normals and Godot lighting produce the terminator. Exactly half of a sphere's surface receives direct parallel sunlight; how much of that hemisphere the camera sees depends on the Sun's direction. With the Sun behind Earth during the eclipse, the camera sees its dark side. A very weak ambient contribution keeps some detail without flattening the day/night boundary. NASA Black Marble data supplies golden city emission on that night side. The shader transforms the fragment normal from view space to world space and compares it with the same world-space Sun direction as the DirectionalLight. A smooth twilight band fades city lights out before direct daylight begins; the map rotates with the geography, not with the camera.
- The visible disc and its local glow use a separate cinematic sky projection. Only their lateral path is compressed to cross the portrait view gradually; their depth follows the physical orbit, from -1,000 units behind Earth through the right-hand side to +1,000 units behind the camera. The Sun node remains the physical direction marker for the DirectionalLight. After the right exit the disc and glow stay hidden during the camera-side half orbit, instead of folding back over Earth on a fixed background plane. The full orbit continues around the viewer and toward the left before another eclipse. This display projection is artistic and does not claim astronomical position or diameter proportions.
- The solar disc has a fixed display radius of 0.12 world units, twice its previous 0.06-unit radius, clamped to at most 2% of the camera width. It never grows to Earth's radius. Its halo radius is only 3.5 times the disc radius. Fades near the viewport edges and camera near plane let it leave quietly to the right and disappear behind the viewer. The eclipse ring uses a narrow annulus, soft halo, and localized bead at contact. `Sun/Flare` adds a focused horizontal anamorphic streak with a short cross-ray as the disc clears the limb, fading away after contact. It is a cinematic lens effect, not volumetric scattering. All glow uses bounded alpha blending; GLES2 bloom and auto exposure are not required.
- Solar irradiance stays constant while the point and halo fade. Their unshaded materials do not light Earth. Only the DirectionalLight's smoothly changing orientation moves the terminator. As the Sun travels behind the camera, more of Earth's camera-facing hemisphere receives sunlight, even though the Sun model is out of view. After the reveal, orbital speed eases in over 0.7 seconds instead of starting abruptly.
- Minimizing smoothly returns the solar direction to side lighting and fades out the corona. Angle targets use the shortest angular path; wrapping an orbit through 360 degrees does not reset Earth or the camera. Each Tween has one progress track, including when the reveal is interrupted by minimization. Normal tap controls work once Earth's approach finishes, even if the Sun is still emerging.

Select the scene root to tune `SunRevealSeconds`, `SunOrbitDegreesPerSecond`, `SunDistance`, `SunRadius`, `SunHaloStrength`, `EclipseHaloStrength`, `SunFlareStrength`, and `SunLightEnergy`. Halo and flare strengths affect only decorative effects; light energy controls direct illumination. `CityLightsStrength` controls golden night emission, and `NightTwilightWidth` sets its smooth fade into the terminator (default 0.18 in normal-dot-light units, approximately 10 degrees). Night emission and flare opacity never animate physical sunlight energy. Every scene instance owns its shader materials. `SunDistance` is clamped to at least 100 world units and the camera's far plane is enlarged at startup if needed. The ordinary Earth expansion and minimization timings still use `ExpansionSeconds` and `TransitionSeconds`.

## Android app preview

1. Install the **matching Godot 3.5.3 Mono export templates** via Editor → Manage Export Templates.
2. Set up OpenJDK 11 and the Android SDK using the [Godot 3.5 Android guide](https://docs.godotengine.org/en/3.5/tutorials/export/exporting_for_android.html).
3. Editor Settings → Export → Android: configure the SDK directory and debug keystore. The repository deliberately contains no signing keys.
4. Project → Export: choose the supplied **Android** preset. Replace `org.example.earthwallpaper` with your own package identifier if distributing it.
5. Export a debug APK to `build/EarthWallpaper.apk` (create the build folder if needed), then install it on a phone with USB debugging enabled.
6. Verify portrait layout, tapping, swipe rejection, both transitions, and steady rotation. Check performance on the actual device.

The APK is an app preview, not an installable Android live-wallpaper service.

## Actual Android live wallpaper

An Android native integration must implement WallpaperService and WallpaperService.Engine, declare BIND_WALLPAPER and wallpaper XML metadata, host Godot's rendering on the service's surface, enable and forward supported touch events, and pause rendering when the wallpaper is invisible. For Godot 3.5.3 Mono, this requires compatible custom Android hosting/templates; it is not accomplished by changing the export preset. Launcher touch forwarding also varies by launcher.

Reference: [Android WallpaperService](https://developer.android.com/reference/android/service/wallpaper/WallpaperService).

## Verification

The project includes `tests/smoke.gd` for the layout, Y rotation, approach gesture, single taps, and swipe/long-press filtering. `tests/sun_lighting.gd` checks the distant light direction, eclipse ring, full solar orbit, continuous framing, camera stability, rotation basis, and collapse. Rendered comparisons test the terminator at several latitudes, left/right/front/back solar directions, and brightness after translating Earth. The lighting check keeps the actual Earth shader and temporarily supplies a flat texture to remove geography from the comparison. Run them with the matching Mono engine after importing resources and building the C# project:

```text
Godot_v3.5.3-stable_mono_win64.exe --no-window --path . --script tests/smoke.gd
Godot_v3.5.3-stable_mono_win64.exe --no-window --path . --script tests/sun_lighting.gd
Godot_v3.5.3-stable_mono_win64.exe --no-window --path . --script tests/eclipse_cinematic.gd
Godot_v3.5.3-stable_mono_win64.exe --no-window --path . --script tests/night_lights.gd
```

`tests/eclipse_cinematic.gd` also captures first contact, crossing, and exit. It checks that the diamond is visible, bright pixels occupy only a small part of the frame, the solar disc stays small, outgoing position/opacity remain continuous, and changing glow opacity leaves Earth's surface lighting unchanged. Its contact preview is saved to `docs/preview-diamond-ring.png`.

`tests/night_lights.gd` tests gold emission on the night side, its absence in daylight, intermediate brightness through twilight, and an actual rendered contact beam beyond the local halo. It checks that the flare fades away after contact and behind the camera without changing sunlight energy. Its previews are `docs/preview-city-night.png` and `docs/preview-city-diamond-flare.png`.
