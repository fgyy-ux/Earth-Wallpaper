shader_type spatial;
// Restrained annular halo. A separate quad provides the focused contact flare.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float bead_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 bead_direction = vec2(1.0, 0.0);

void fragment() {
    vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
    float radius = length(p);
    float line = exp(-pow((radius - 0.9) / 0.006, 2.0));
    float halo = exp(-pow((radius - 0.9) / 0.027, 2.0));
    float arc = pow(max(dot(p / max(radius, 0.001), bead_direction), 0.0), 160.0);
    ALBEDO = vec3(1.0, 0.86, 0.58);
    ALPHA = clamp(strength, 0.0, 1.0) * (line * 0.2 + halo * 0.08)
        + clamp(bead_strength, 0.0, 1.0) * arc * halo * 0.55;
}
