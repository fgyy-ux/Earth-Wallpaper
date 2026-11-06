shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D earth_texture : hint_albedo;
uniform sampler2D night_texture : hint_black;
uniform vec3 sun_direction_world = vec3(0.965926, 0.258819, 0.0);
uniform float city_lights_strength : hint_range(0.0, 2.0) = 0.85;
uniform float night_twilight_width : hint_range(0.02, 0.4) = 0.18;

void fragment() {
    vec3 surface = texture(earth_texture, UV).rgb;
    // Parallel sunlight and surface normals define the great-circle terminator.
    // Diffuse reflection preserves the texture without a concentrated glare.
    ALBEDO = surface;
    METALLIC = 0.0;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;

    // NORMAL is in view space in Godot 3's fragment stage. Use the same world
    // direction as the real DirectionalLight, rather than a fixed UV mask.
    vec3 world_normal = normalize((CAMERA_MATRIX * vec4(NORMAL, 0.0)).xyz);
    float incidence = dot(world_normal, normalize(sun_direction_world));
    float night = 1.0 - smoothstep(-night_twilight_width, -0.005, incidence);
    float radiance = texture(night_texture, UV).r;
    // Reject the satellite map's weak background, retaining soft urban points.
    float cities = pow(smoothstep(0.08, 0.65, radiance), 1.3);
    EMISSION = vec3(1.0, 0.62, 0.22) * cities * city_lights_strength * night;
}
