extends SceneTree

var failures = []
var scene
var globe
var sun
var light
var camera

func _init():
    call_deferred("run_checks")

func check(condition, message):
    if not condition:
        failures.append(message)
        printerr("FAIL: " + message)

func wait_seconds(seconds):
    yield(create_timer(seconds), "timeout")

func capture(path = ""):
    var image = get_root().get_texture().get_data()
    image.flip_y()
    if path != "":
        image.save_png(path)
    return image

func brightness(image, world_position):
    var point = camera.unproject_position(world_position)
    # The viewport uses logical coordinates; its render texture can have a
    # different resolution when portrait stretching/test-window scaling is on.
    point *= Vector2(image.get_width(), image.get_height()) / get_root().get_visible_rect().size
    var total = 0.0
    image.lock()
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            var color = image.get_pixel(int(point.x) + dx, int(point.y) + dy)
            total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
    image.unlock()
    return total / 25.0

func emitter_matches_model():
    var toward_sun = (sun.global_transform.origin - globe.global_transform.origin).normalized()
    return light.global_transform.origin.distance_to(sun.global_transform.origin) < 0.001 \
        and light.global_transform.basis.z.dot(toward_sun) > 0.9999

func check_motion(seconds):
    var previous = globe.translation
    var previous_solar_direction = light.global_transform.basis.z
    var camera_pose = camera.global_transform
    var previous_time = OS.get_ticks_msec()
    var end_time = previous_time + int(seconds * 1000)
    while OS.get_ticks_msec() < end_time:
        yield(VisualServer, "frame_post_draw")
        var now = OS.get_ticks_msec()
        # Sample completed frames, including the engine's elapsed step. A GPU
        # readback before this check can lengthen its first engine frame.
        var dt = max(scene.get_process_delta_time(), (now - previous_time) / 1000.0)
        dt = max(dt, 1.0 / max(1, Engine.target_fps))
        check(globe.translation.distance_to(previous) < 15.0 * dt + 0.05,
            "Earth position changes continuously across tween boundaries (step=%s, dt=%s)" %
            [globe.translation.distance_to(previous), dt])
        var right_edge = camera.unproject_position(globe.global_transform.origin + Vector3.RIGHT * globe.scale.x)
        check(right_edge.x > 0, "Earth remains inside the left edge of the portrait frame")
        check(globe.global_transform.origin.z + globe.scale.z < camera.global_transform.origin.z - camera.near,
            "Earth never crosses the camera near plane")
        var basis = scene.get_node("EarthRoot/Spin").transform.basis
        check(abs(basis.determinant() - 1.0) < 0.0001,
            "spin preserves an orthonormal, unscaled mesh basis")
        check(basis.is_equal_approx(basis.orthonormalized()), "spin contains no shear")
        check(camera.global_transform.is_equal_approx(camera_pose), "camera stays fixed on every sampled frame")
        check(emitter_matches_model(), "parallel sunlight stays aligned with the distant Sun")
        check(previous_solar_direction.angle_to(light.global_transform.basis.z) < 20.0 * dt + 0.05,
            "solar direction remains continuous across angle wrap and tween boundaries (step=%s, dt=%s, speed=%s)" %
            [previous_solar_direction.angle_to(light.global_transform.basis.z), dt, scene.get("SunOrbitDegreesPerSecond")])
        previous = globe.translation
        previous_solar_direction = light.global_transform.basis.z
        previous_time = now

func run_checks():
    scene = load("res://scenes/EarthWallpaper.tscn").instance()
    get_root().size = Vector2(720, 1280)
    get_root().add_child(scene)
    globe = scene.get_node("EarthRoot")
    sun = scene.get_node("Sun")
    light = scene.get_node("Sun/SunLight")
    camera = scene.get_node("Camera")
    check(light is DirectionalLight, "sunlight is directional, not a point light")
    check(emitter_matches_model(), "light points from the distant Sun toward Earth")
    check(abs(sun.global_transform.origin.distance_to(globe.global_transform.origin) - 1000.0) < 0.01,
        "Sun starts at a distant, fixed orbital radius")
    var initial_camera = camera.global_transform
    # Finish initial texture/shader uploads before starting timed animations.
    yield(VisualServer, "frame_post_draw")
    yield(VisualServer, "frame_post_draw")

    var reveal_seconds = float(scene.get("SunRevealSeconds"))
    scene.call("SetExpanded", true)
    yield(check_motion(reveal_seconds * 0.33), "completed")
    check(sun.global_transform.origin.z < globe.global_transform.origin.z - globe.scale.x,
        "Sun remains behind Earth during the ring phase")
    check(sun.get_node("Core").scale.x < globe.scale.x, "solar disc is covered during eclipse")
    check(scene.get_node("EclipseRing").material_override.get_shader_param("strength") > 0.5,
        "separate Earth-centered halo becomes visible before Sun emerges")
    check(emitter_matches_model(), "ring-phase illumination follows hidden Sun")
    var ring_image = capture("res://docs/preview-sun-ring.png")
    check(abs(sun.global_transform.origin.x - globe.global_transform.origin.x) < 0.01,
        "ring phase keeps the distant Sun aligned behind Earth")
    check(brightness(ring_image, globe.global_transform.origin + Vector3.RIGHT * globe.scale.x * 1.017) > 0.04,
        "eclipse corona is rendered outside the Earth silhouette")

    yield(check_motion(reveal_seconds * 0.67 + 0.2), "completed")
    check(not scene.get_node("SunTween").is_active(), "Sun reveal completes")
    check(sun.global_transform.origin.x > globe.global_transform.origin.x + 900,
        "Sun reaches Earth's right at the configured distant orbital radius")
    check(emitter_matches_model(), "emerged sunlight follows Sun model")
    capture("res://docs/preview-sun-emerged.png")
    var orbit_start = sun.global_transform.origin
    var stationary_earth = globe.transform
    scene.set("SunOrbitDegreesPerSecond", 720.0)
    yield(check_motion(1.2), "completed")
    scene.set("SunOrbitDegreesPerSecond", 8.0)
    check(sun.global_transform.origin.distance_to(orbit_start) > 0.1, "Sun continues orbiting after reveal")
    check(emitter_matches_model(), "orbiting light stays attached to Sun")
    check(globe.transform.is_equal_approx(stationary_earth), "a full solar orbit cannot shift or scale Earth")
    check(camera.global_transform.is_equal_approx(initial_camera), "camera does not follow the solar orbit")
    check(abs(sun.global_transform.origin.distance_to(globe.global_transform.origin) - 1000.0) < 0.01,
        "Earth enlargement never changes the solar orbit radius")

    var before_collapse = sun.global_transform.origin
    scene.call("SetExpanded", false)
    check(sun.global_transform.origin.distance_to(before_collapse) < 0.001,
        "collapse does not teleport the Sun or light")
    yield(check_motion(0.65), "completed")
    check(not scene.get_node("SunTween").is_active(), "Sun returns to compact side lighting on collapse")
    check(emitter_matches_model(), "collapsed light still matches Sun")

    # Reverse before the longer solar reveal completes, then do it again.
    for cycle in range(2):
        scene.call("SetExpanded", true)
        yield(check_motion(0.9), "completed")
        check(scene.get_node("SunTween").is_active(), "test interrupts an active solar reveal")
        var before_reverse_earth = globe.transform
        var before_reverse_sun = sun.global_transform
        scene.call("SetExpanded", false)
        check(globe.transform.is_equal_approx(before_reverse_earth), "reversing reveal does not teleport Earth")
        check(sun.global_transform.is_equal_approx(before_reverse_sun), "reversing reveal does not teleport Sun")
        yield(check_motion(0.65), "completed")
        check(globe.translation.distance_to(Vector3(-1.35, 1.15, 0)) < 0.001,
            "repeated toggles restore the original Earth position")

    # Keep the actual Earth shader, replacing only its texture with flat gray.
    # This tests the lighting rather than geography or the idle spin.
    scene.set_process(false)
    globe.translation = Vector3.ZERO
    globe.scale = Vector3.ONE
    var gray = Image.new()
    gray.create(4, 4, false, Image.FORMAT_RGBA8)
    gray.fill(Color(0.6, 0.6, 0.6, 1))
    var texture = ImageTexture.new()
    texture.create_from_image(gray, 0)
    var earth_mesh = scene.get_node("EarthRoot/Spin/EarthMesh")
    var material = earth_mesh.material_override
    material.set_shader_param("earth_texture", texture)
    # Isolate direct sunlight from the new emissive night texture.
    scene.set("CityLightsStrength", 0.0)
    scene.call("ApplySunAppearance", 1.0)

    scene.call("ApplySunAngle", PI * 0.5)
    yield(wait_seconds(0.15), "completed")
    var right_sun = capture("res://build/validation/light-right.png")
    var right_lit = brightness(right_sun, Vector3(0.65, 0, 0))
    var right_dark = brightness(right_sun, Vector3(-0.65, 0, 0))
    check(right_lit > right_dark + 0.05, "right-side Sun lights Earth's right side")
    # The terminator crosses the center at different latitudes. A nearby point
    # emitter would light a smaller cap and shift this boundary toward the Sun.
    for latitude in [-0.5, 0.0, 0.5]:
        var boundary_x = -latitude * tan(deg2rad(15.0))
        check(brightness(right_sun, Vector3(boundary_x + 0.35, latitude, 0)) >
            brightness(right_sun, Vector3(boundary_x - 0.35, latitude, 0)) + 0.04,
            "great-circle terminator spans the sphere at each sampled latitude")
    globe.translation = Vector3(0.5, 0, 0)
    scene.call("ApplySunAngle", PI * 0.5)
    yield(wait_seconds(0.15), "completed")
    var translated_lit = brightness(capture(), Vector3(1.15, 0, 0))
    check(abs(translated_lit - right_lit) < 0.02,
        "parallel sunlight has no position-dependent hotspot or distance falloff")
    globe.translation = Vector3.ZERO

    scene.call("ApplySunAngle", PI * 1.5)
    yield(wait_seconds(0.15), "completed")
    var left_sun = capture("res://build/validation/light-left.png")
    var left_lit = brightness(left_sun, Vector3(-0.65, 0, 0))
    var left_dark = brightness(left_sun, Vector3(0.65, 0, 0))
    check(left_lit > left_dark + 0.05, "left-side Sun lights Earth's left side")

    scene.call("ApplySunAngle", 0.0)
    yield(wait_seconds(0.15), "completed")
    var behind = brightness(capture("res://build/validation/light-back.png"), Vector3(0.65, 0, 0))
    scene.call("ApplySunAngle", PI)
    yield(wait_seconds(0.15), "completed")
    var in_front = brightness(capture("res://build/validation/light-front.png"), Vector3(0.65, 0, 0))
    check(in_front > behind + 0.05, "front Sun illuminates the visible hemisphere; hidden Sun leaves it dark")
    var core = sun.get_node("Core")
    check(core.global_transform.origin.z > camera.global_transform.origin.z,
        "front-lighting Sun model is physically behind the camera")
    check(not core.visible, "camera-side Sun lights Earth without drawing a disc over its surface")
    print("Lighting luminance: right ", right_lit, "/", right_dark,
        ", left ", left_lit, "/", left_dark, ", back/front ", behind, "/", in_front)

    if failures.empty():
        print("PASS: distant directional Sun, terminator, translation-invariant lighting, full orbit, continuous framing, and smooth collapse")
    quit(0 if failures.empty() else 1)
