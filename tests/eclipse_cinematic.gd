extends SceneTree

var scene
var globe
var core
var camera
var failures = []

func _init():
    call_deferred("run_checks")

func check(condition, message):
    if not condition:
        failures.append(message)
        printerr("FAIL: " + message)

func capture(path):
    var image = get_root().get_texture().get_data()
    image.flip_y()
    image.save_png(path)
    return image

func bright_fraction(image):
    var bright = 0
    var samples = 0
    image.lock()
    for y in range(0, image.get_height(), 3):
        for x in range(0, image.get_width(), 3):
            var c = image.get_pixel(x, y)
            if c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722 > 0.8:
                bright += 1
            samples += 1
    image.unlock()
    return float(bright) / samples

func contact_brightness(image):
    # Measure the actual render texture. A hidden desktop window may have a
    # different client height from the forced portrait viewport. This camera
    # is orthographic/Keep Width, so world units map directly to image width.
    var local = camera.global_transform.affine_inverse().xform(core.global_transform.origin)
    var pixels_per_unit = float(image.get_width()) / camera.size
    var point = Vector2(image.get_width() * 0.5, image.get_height() * 0.5) + \
        Vector2(local.x, -local.y) * pixels_per_unit
    var peak = 0.0
    image.lock()
    for dy in range(-12, 13):
        for dx in range(-12, 13):
            var c = image.get_pixel(int(point.x) + dx, int(point.y) + dy)
            peak = max(peak, c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722)
    image.unlock()
    return peak

func run_checks():
    scene = load("res://scenes/EarthWallpaper.tscn").instance()
    get_root().size = Vector2(720, 1280)
    get_root().add_child(scene)
    globe = scene.get_node("EarthRoot")
    core = scene.get_node("Sun/Core")
    camera = scene.get_node("Camera")
    yield(VisualServer, "frame_post_draw")
    yield(VisualServer, "frame_post_draw")
    scene.set_process(false)
    scene.call("SetExpanded", true)
    scene.get_node("Tween").stop_all()
    scene.get_node("SunTween").stop_all()
    scene.call("ApplyEarthTransition", 1.0)

    # Find first contact from actual geometry, rather than a hardcoded instant.
    var low = 0.4
    var high = 1.0
    for step in range(24):
        var middle = (low + high) * 0.5
        scene.call("ApplySunTransition", middle)
        var offset = core.global_transform.origin - globe.global_transform.origin
        if Vector2(offset.x, offset.y).length() < globe.scale.x - 0.02:
            low = middle
        else:
            high = middle
    var contact_progress = (low + high) * 0.5
    var light = scene.get_node("Sun/SunLight")
    var energy = light.light_energy
    var peak_fraction = 0.0
    for phase in [0.33, contact_progress, 0.73, 0.84, 0.94, 1.0]:
        scene.call("ApplySunTransition", phase)
        yield(VisualServer, "frame_post_draw")
        var name = "diamond" if abs(phase - contact_progress) < 0.0001 else str(int(phase * 100))
        var image = capture("res://build/validation/eclipse-" + name + ".png")
        if name == "diamond":
            image.save_png("res://docs/preview-diamond-ring.png")
            check(contact_brightness(image) > 0.65, "a bright diamond is actually rendered at first contact")
        peak_fraction = max(peak_fraction, bright_fraction(image))
        var radius = core.global_transform.basis.x.length()
        check(radius <= camera.size * 0.02 + 0.0001, "Sun disc stays small throughout emergence")
        check(abs(radius - 0.12) < 0.0001, "Sun's displayed radius is doubled to 0.12 units")
        check(abs(light.light_energy - energy) < 0.0001, "glow does not animate solar irradiance")
        check(bright_fraction(image) < 0.008, "no frame has a broad blinding solar flare")
    check(core.material_override.get_shader_param("visibility") < 0.01, "Sun fades out beyond the right edge")

    # Dense geometry sampling catches motion/opacity jumps without render noise.
    var previous_position = Vector3.ZERO
    var previous_opacity = 0.0
    for step in range(1001):
        scene.call("ApplySunTransition", step / 1000.0)
        var position = core.global_transform.origin
        var opacity = float(core.material_override.get_shader_param("visibility"))
        # The initial, hidden incoming pass is deliberately compressed. Check
        # the visible outgoing passage, including contact and the edge fade.
        if step >= 400:
            # Lateral movement should stay gentle. Orbital depth is deliberately
            # much larger, so measure the visible sky displacement separately.
            var sky_step = camera.global_transform.basis.x.dot(position - previous_position)
            check(abs(sky_step) < 0.15, "displayed Sun moves without lateral coordinate jumps")
            check(abs(opacity - previous_opacity) < 0.1, "solar visibility fades smoothly")
        previous_position = position
        previous_opacity = opacity

    # Right exit -> behind the viewer, rather than folding back onto the sky
    # behind Earth. Check both geometry and opacity throughout that half orbit.
    scene.call("ApplySunAppearance", 1.0)
    for degrees in range(100, 261, 10):
        scene.call("ApplySunAngle", deg2rad(degrees))
        var in_camera = camera.global_transform.affine_inverse().xform(core.global_transform.origin)
        check(in_camera.z > 0, "solar disc passes physically behind the camera")
        check(not core.visible, "Sun cannot reappear over Earth during the camera-side half orbit")
        check(scene.get_node("Sun/Corona").material_override.get_shader_param("strength") < 0.001,
            "the local solar halo stays hidden behind the camera")
        check(light.global_transform.basis.z.dot(camera.global_transform.basis.z) > 0,
            "camera-side Sun illuminates Earth's camera-facing hemisphere")
        check(abs(light.light_energy - energy) < 0.0001, "behind-camera travel preserves solar irradiance")
    scene.call("ApplySunAngle", PI)
    yield(VisualServer, "frame_post_draw")
    capture("res://docs/preview-sun-behind-camera.png")

    # Pure glow changes cannot alter surface brightness on Earth.
    scene.call("ApplySunAngle", PI * 0.5)
    scene.call("ApplySunAppearance", 1.0)
    yield(VisualServer, "frame_post_draw")
    var lit = capture("res://build/validation/eclipse-light-stable.png")
    scene.call("ApplySunAppearance", 0.0)
    yield(VisualServer, "frame_post_draw")
    var hidden = capture("res://build/validation/eclipse-light-no-glow.png")
    var point = camera.unproject_position(globe.global_transform.origin + Vector3.RIGHT * globe.scale.x * 0.8)
    point *= Vector2(lit.get_width(), lit.get_height()) / get_root().get_visible_rect().size
    lit.lock()
    hidden.lock()
    check(lit.get_pixelv(point).is_equal_approx(hidden.get_pixelv(point)), "Earth lighting is independent of display glow opacity")
    lit.unlock()
    hidden.unlock()
    if failures.empty():
        print("PASS: doubled Sun, diamond contact, gradual traversal, behind-camera orbit, stable light; peak bright fraction ", peak_fraction)
    quit(0 if failures.empty() else 1)
