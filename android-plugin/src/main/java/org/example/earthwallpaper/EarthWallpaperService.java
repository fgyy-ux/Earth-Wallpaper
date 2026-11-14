package org.example.earthwallpaper;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.BitmapShader;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.os.Handler;
import android.os.Looper;
import android.service.wallpaper.WallpaperService;
import android.view.MotionEvent;
import android.view.SurfaceHolder;

import java.io.IOException;
import java.io.InputStream;
import java.util.Random;

/** Lightweight Android Surface renderer for the Earth live wallpaper. */
public final class EarthWallpaperService extends WallpaperService {
    @Override
    public Engine onCreateEngine() {
        return new EarthEngine();
    }

    private final class EarthEngine extends Engine {
        private static final long FRAME_DELAY_MS = 33L;
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        private final Paint earthPaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        private final Paint nightPaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        private final Paint overlayPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint glowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Random random = new Random(5303L);
        private Bitmap dayMap;
        private Bitmap nightMap;
        private float width;
        private float height;
        private float expand = 0.0f;
        private float targetExpand = 0.0f;
        private float yaw;
        private float reveal;
        private long lastFrameNanos;
        private long transitionStartNanos;
        private float transitionStart;
        private long revealStartNanos;
        private boolean visible;
        private float downX;
        private float downY;
        private long downTime;
        private final float[] starsX = new float[72];
        private final float[] starsY = new float[72];

        private final Runnable frame = new Runnable() {
            @Override
            public void run() {
                if (!visible) return;
                drawFrame();
                handler.postDelayed(this, FRAME_DELAY_MS);
            }
        };

        EarthEngine() {
            setTouchEventsEnabled(true);
            loadTextures();
            for (int i = 0; i < starsX.length; i++) {
                starsX[i] = random.nextFloat();
                starsY[i] = random.nextFloat();
            }
        }

        private void loadTextures() {
            try {
                dayMap = decodeAsset("earth.png");
                nightMap = decodeAsset("earth_night.jpg");
            } catch (IOException ignored) {
                dayMap = null;
                nightMap = null;
            }
        }

        private Bitmap decodeAsset(String name) throws IOException {
            InputStream stream = getAssets().open(name);
            try {
                return BitmapFactory.decodeStream(stream);
            } finally {
                stream.close();
            }
        }

        @Override
        public void onSurfaceChanged(SurfaceHolder holder, int format, int pixelWidth, int pixelHeight) {
            super.onSurfaceChanged(holder, format, pixelWidth, pixelHeight);
            width = pixelWidth;
            height = pixelHeight;
            drawFrame();
        }

        @Override
        public void onVisibilityChanged(boolean isVisible) {
            visible = isVisible;
            handler.removeCallbacks(frame);
            if (visible) handler.post(frame);
        }

        @Override
        public void onSurfaceDestroyed(SurfaceHolder holder) {
            visible = false;
            handler.removeCallbacks(frame);
            super.onSurfaceDestroyed(holder);
        }

        @Override
        public void onDestroy() {
            visible = false;
            handler.removeCallbacks(frame);
            if (dayMap != null) dayMap.recycle();
            if (nightMap != null) nightMap.recycle();
            super.onDestroy();
        }

        @Override
        public void onTouchEvent(MotionEvent event) {
            if (event.getAction() == MotionEvent.ACTION_DOWN) {
                downX = event.getX();
                downY = event.getY();
                downTime = System.currentTimeMillis();
            } else if (event.getAction() == MotionEvent.ACTION_UP) {
                float dx = event.getX() - downX;
                float dy = event.getY() - downY;
                if (dx * dx + dy * dy < 24.0f * 24.0f &&
                        System.currentTimeMillis() - downTime < 350L) {
                    targetExpand = targetExpand < 0.5f ? 1.0f : 0.0f;
                    transitionStart = expand;
                    transitionStartNanos = System.nanoTime();
                    if (targetExpand > 0.5f) revealStartNanos = transitionStartNanos;
                }
            }
            super.onTouchEvent(event);
        }

        private void drawFrame() {
            SurfaceHolder holder = getSurfaceHolder();
            Canvas canvas = null;
            try {
                canvas = holder.lockCanvas();
                if (canvas == null) return;
                width = canvas.getWidth();
                height = canvas.getHeight();
                long now = System.nanoTime();
                float dt = lastFrameNanos == 0L ? 0.033f : Math.min(0.1f, (now - lastFrameNanos) / 1.0e9f);
                lastFrameNanos = now;
                yaw = (yaw + dt * 0.11f) % 1.0f;
                float duration = targetExpand > expand ? 1.4f : 0.65f;
                float t = transitionStartNanos == 0L ? 1.0f : Math.min(1.0f, (now - transitionStartNanos) / (duration * 1.0e9f));
                float eased = t * t * (3.0f - 2.0f * t);
                expand = transitionStart + (targetExpand - transitionStart) * eased;
                if (t >= 1.0f) transitionStartNanos = 0L;
                if (targetExpand > 0.5f && revealStartNanos != 0L) {
                    reveal = Math.min(1.0f, (now - revealStartNanos) / 7.2e9f);
                } else if (targetExpand < 0.5f) {
                    reveal = Math.max(0.0f, reveal - dt * 0.8f);
                }
                render(canvas, now);
            } catch (RuntimeException ignored) {
                // Surface can disappear between visibility and frame callbacks.
            } finally {
                if (canvas != null) holder.unlockCanvasAndPost(canvas);
            }
        }

        private void render(Canvas canvas, long now) {
            canvas.drawColor(Color.rgb(3, 7, 18));
            for (int i = 0; i < starsX.length; i++) {
                float pulse = 0.55f + 0.45f * (float)Math.sin(now / 1.0e9f + i * 1.73f);
                paint.setColor(Color.argb((int)(70 * pulse), 190, 215, 255));
                float radius = (i % 8 == 0) ? 2.0f : 1.0f;
                canvas.drawCircle(starsX[i] * width, starsY[i] * height, radius, paint);
            }

            float radius = height * (0.19f + 0.34f * expand);
            float centerX = width * (0.36f - 0.48f * expand);
            float centerY = height * (0.43f + 0.07f * expand);
            float left = centerX - radius;
            float top = centerY - radius;
            float diameter = radius * 2.0f;
            RectF globe = new RectF(left, top, left + diameter, top + diameter);

            if (dayMap != null) {
                earthPaint.setShader(bitmapShader(dayMap, diameter, yaw));
                canvas.drawCircle(centerX, centerY, radius, earthPaint);
                earthPaint.setShader(null);
            } else {
                paint.setShader(new RadialGradient(centerX - radius * 0.25f, centerY - radius * 0.2f,
                        radius * 1.2f, new int[]{0xff418bd0, 0xff09244d, 0xff020612}, null, Shader.TileMode.CLAMP));
                canvas.drawCircle(centerX, centerY, radius, paint);
                paint.setShader(null);
            }

            int save = canvas.save();
            canvas.clipPath(circlePath(centerX, centerY, radius));
            float lightX = centerX + (float)Math.cos(now / 1.0e10) * radius;
            float darkX = lightX + (lightX < centerX ? radius : -radius);
            overlayPaint.setShader(new LinearGradient(lightX, centerY, darkX, centerY,
                    new int[]{0x00000000, 0x8a02050d, 0xc802050d}, new float[]{0.0f, 0.55f, 1.0f}, Shader.TileMode.CLAMP));
            canvas.drawRect(globe, overlayPaint);
            overlayPaint.setShader(null);
            if (nightMap != null) {
                nightPaint.setAlpha((int)(Math.max(0.0f, 1.0f - Math.abs(lightX - centerX) / (radius * 1.8f)) * 105));
                nightPaint.setShader(bitmapShader(nightMap, diameter, yaw));
                canvas.drawCircle(centerX, centerY, radius, nightPaint);
                nightPaint.setShader(null);
                nightPaint.setAlpha(255);
            }
            canvas.restoreToCount(save);

            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(Math.max(1.0f, radius * 0.012f));
            paint.setColor(0x663f91e8);
            canvas.drawCircle(centerX, centerY, radius, paint);
            paint.setStyle(Paint.Style.FILL);

            if (reveal > 0.01f) {
                float sunX = centerX + radius * (0.72f + 1.35f * reveal);
                float sunY = centerY - radius * 0.12f;
                float sunRadius = Math.max(4.0f, radius * 0.055f);
                glowPaint.setShader(new RadialGradient(sunX, sunY, sunRadius * 5.0f,
                        new int[]{0x88ffd27a, 0x22ffb548, 0x00ff9d36}, null, Shader.TileMode.CLAMP));
                canvas.drawCircle(sunX, sunY, sunRadius * 5.0f, glowPaint);
                glowPaint.setShader(null);
                paint.setColor(0xffffe3a0);
                canvas.drawCircle(sunX, sunY, sunRadius, paint);
            }
        }

        private BitmapShader bitmapShader(Bitmap bitmap, float diameter, float rotation) {
            BitmapShader shader = new BitmapShader(bitmap, Shader.TileMode.REPEAT, Shader.TileMode.CLAMP);
            Matrix matrix = new Matrix();
            matrix.setScale(diameter / bitmap.getWidth(), diameter / bitmap.getHeight());
            matrix.postRotate(rotation * 360.0f, diameter * 0.5f, diameter * 0.5f);
            shader.setLocalMatrix(matrix);
            return shader;
        }

        private android.graphics.Path circlePath(float x, float y, float r) {
            android.graphics.Path path = new android.graphics.Path();
            path.addCircle(x, y, r, android.graphics.Path.Direction.CW);
            return path;
        }
    }
}
