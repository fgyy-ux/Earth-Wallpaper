shader_type spatial;
// Cinematic lens response, not a volumetric light or an extra emitter.
// Depth testing lets the opaque Earth cut off the hidden half of the streak.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float taper = 1.0 - smoothstep(0.1, 1.0, abs(p.x));
    float streak = exp(-pow(p.y / 0.035, 2.0)) * taper * taper;
    float glow = exp(-pow(p.y / 0.18, 2.0)) * exp(-abs(p.x) * 4.0) * taper;
    float cross_ray = exp(-pow(p.x / 0.025, 2.0)) * pow(max(1.0 - abs(p.y), 0.0), 4.0);
    ALBEDO = vec3(1.0, 0.86, 0.57);
    ALPHA = clamp(strength, 0.0, 1.0) * min(0.85, streak * 0.68 + glow * 0.15 + cross_ray * 0.12);
}
