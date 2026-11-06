shader_type spatial;
// A small local glow, never a globe-sized additive flare. Earth occludes it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float radius = length(p);
    float glow = exp(-radius * radius * 5.0) * (1.0 - smoothstep(0.65, 1.0, radius));
    ALBEDO = vec3(1.0, 0.78, 0.42);
    ALPHA = 0.24 * clamp(strength, 0.0, 1.0) * glow;
}
