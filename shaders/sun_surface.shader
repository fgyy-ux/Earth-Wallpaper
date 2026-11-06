shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform float visibility : hint_range(0.0, 1.0) = 0.0;

varying vec3 surface_position;

void vertex() {
    surface_position = VERTEX;
}

void fragment() {
    float cells = sin(surface_position.x * 30.0 + TIME * 0.35)
        * sin(surface_position.y * 33.0 - TIME * 0.2)
        * sin(surface_position.z * 29.0 + TIME * 0.15);
    float face = clamp(normalize(NORMAL).z, 0.0, 1.0);
    vec3 warm = mix(vec3(1.0, 0.24, 0.025), vec3(1.0, 0.94, 0.67), pow(face, 0.45));
    ALBEDO = warm * (0.975 + cells * 0.025);
    ALPHA = clamp(visibility, 0.0, 1.0);
}
