package org.example.earthwallpaper;

import android.app.WallpaperManager;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Build;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/** Godot 3.5.3 Android plugin bridge for opening the system wallpaper preview. */
public final class EarthLiveWallpaperPlugin extends GodotPlugin {
    public EarthLiveWallpaperPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "EarthLiveWallpaper";
    }

    @UsedByGodot
    public void openWallpaperPicker() {
        final Godot activity = getGodot();
        activity.runOnUiThread(() -> {
            ComponentName service = new ComponentName(
                    activity, EarthWallpaperService.class);
            Intent intent;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                intent = new Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER);
                intent.putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, service);
            } else {
                intent = new Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER);
            }
            activity.startActivity(intent);
        });
    }
}
