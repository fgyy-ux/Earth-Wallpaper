# Earth live wallpaper Android plugin (Godot 3.5.3)

This module adds an Android `WallpaperService` that renders a native, lightweight Earth wallpaper from the project's `earth.png` and `earth_night.jpg` textures. A tap expands/minimizes the globe. The `EarthLiveWallpaper` Godot singleton opens Android's live-wallpaper preview and apply screen.

The service is a native Android renderer of the same textures and interaction. Godot 3.5.3's Java plugin API does not host the running Godot scene or C# renderer on a `WallpaperService` surface, so this does not execute `EarthWallpaper.cs` inside the wallpaper process. That would require modifying the Godot Android engine/template to attach its renderer to the service surface.

## Build the plugin AAR

1. Install the Godot 3.5.3-stable Mono Android export templates and Android custom-build template.
2. Copy the matching `godot-lib.3.5.3.stable.release.aar` from the Godot Android build template into `earthlivewallpaper/libs/`.
3. Open `android-plugin` in Android Studio. Its Gradle module already points to the canonical source set at `android-plugin/src/main`.
4. Build with Android Studio/JDK 11 and the Android SDK installed: `gradlew :earthlivewallpaper:assembleRelease`.
5. Copy `earthlivewallpaper/build/outputs/aar/earthlivewallpaper-release.aar` into the Godot project's `android/plugins/` directory as `EarthLiveWallpaper.release.aar`, and copy `EarthLiveWallpaper.gdap` there too.
6. In Project > Export > Android, enable **Custom Build** and enable **EarthLiveWallpaper** under Plugins. Export/install the APK.

The AAR manifest declares the wallpaper service, the required `BIND_WALLPAPER` service permission, `android.service.wallpaper.WallpaperService` intent filter, and the `@xml/earth_wallpaper` metadata resource. Android's system preview then lets the user apply the wallpaper.

From C#, call `OpenAndroidWallpaperPicker()` on the scene root, for example from a button's `pressed` signal. The method is a no-op in the editor and on non-Android platforms.
