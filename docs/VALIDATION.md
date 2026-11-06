# Validation results

Revalidated on October 24, 2026, with the official Godot 3.5.3-stable Mono Windows x64 engine, directly from `D:\Artur's Folder\Wallpaper Project`.

- C# Debug build: passed, 0 warnings, 0 errors.
- Scene loading and initial compact upper-left layout: passed.
- Continuous clockwise Y-axis rotation: checked in the script; runtime rotation advances.
- Single native touch on the globe or empty background toggles expansion: passed.
- Desktop mouse tap and minimization: passed.
- Background swipes and long presses do not toggle the view: passed.
- Expansion begins with a slight rightward move and an extra clockwise turn: passed.
- Expansion takes longer than the previous half-second transition: passed.
- The rightward move settles at the vertically centered cropped position and original scale: passed.
- Expanded Earth center projects to the vertical midpoint of the viewport: passed.
- Both final Tween translation/scale targets: passed.
- Expanded globe center moves off screen to the left, exposing only its right side: passed.
- Expanded right edge reaches approximately halfway across the screen, and globe diameter covers most of the portrait height: passed.
- Tapping the visible portion of the cropped globe minimizes it: passed.
- Rendered portrait previews saved in docs.
- Eclipse corona appears while the Sun disc is hidden behind Earth: passed; preview inspected.
- Sun emerges to the right and continues orbiting: passed.
- SunLight stays at the exact Sun model center throughout reveal, orbit, and collapse: passed.
- Minimization returns the Sun smoothly without teleporting the light: passed.
- Rendered surface-light direction with the real Earth shader and a neutral texture: passed. Right/left Sun positions light the corresponding Earth side; a front Sun illuminates the visible hemisphere while a rear Sun leaves it dark.

Measured lit/dark luminance in the direction test was approximately 0.49/0.03 with the Sun on the right, 0.44/0.03 on the left, and 0.66/0.03 for front/back positions.

The checks inject touch/mouse events into the local viewport. Physical Android performance and an APK export have not been tested. No Android WallpaperService is included.

## Previews

- preview-minimized.png
- preview-transition-right.png
- preview-expanded.png
- preview-sun-ring.png
- preview-sun-emerged.png

## Build notes

.NET SDK 10.0.201 successfully built the Godot 3 net472 project.

The Mono runtime reported a debugger-agent port binding warning. It did not prevent script execution, rendering, or interaction checks.

The command-line editor import reported a duplicate Earth texture resource warning. The runtime loaded and rendered the Earth texture successfully.

Current import, build, and runtime logs are in `build/validation/`.
