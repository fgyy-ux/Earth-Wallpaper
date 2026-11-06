extends SceneTree

var failures = []
var scene
var globe
var camera

func _init():
    call_deferred("run_checks")

func check(condition, message):
    if not condition:
        failures.append(message)
        printerr("FAIL: " + message)

func capture(path = ""):
    var image = get_root().get_texture().get_data()
    image.flip_y()
    if path != "":
        image.save_png(path)
    return image

func pixel_position(image, world):
    # Orthographic Keep Width; sample the actual render target even if a hidden
    # desktop window's client height differs from the forced portrait viewport.
    var local = camera.global_transform.affine_inverse().xform(world)
    return Vector2(image.get_width(), image.get_height()) * 0.5 + \
        Vector2(local.x, -local.y) * image.get_width() / camera.size

func sample_color(image, world):
    var p = pixel_position(image, world)
    var total = Color(0, 0, 0, 0)
    image.lock()
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            total += image.get_pixel(int(p.x) + dx, int(p.y) + dy)
    image.unlock()
    return total / 25.0

func luminance(color):
    return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

func solid_texture(color):
    var image = Image.new()
    image.create(4, 4, false, Image.FORMAT_RGB8)
    image.fill(color)
    var texture = ImageTexture.new()
    texture.create_from_image(image, 0)
    return texture

func run_checks():
    scene = load("res://scenes/EarthWallpaper.tscn").instance()
    get_root().size = Vector2(720, 1280)
    get_root().add_child(scene)
    globe = scene.get_node("EarthRoot")
    camera = scene.get_node("Camera")
    yield(VisualServer, "frame_post_draw")
    yield(VisualServer, "frame_post_draw")
    scene.set_process(false)
    globe.translation = Vector3.ZERO
    globe.scale = Vector3.ONE
    var material = scene.get_node("EarthRoot/Spin/EarthMesh").material_override
    var original_day = material.get_shader_param("earth_texture")
    var original_night = material.get_shader_param("night_texture")
    check(original_night != null, "NASA city-light texture is included")
    check(original_night.get_width() <= 1024, "night map is imported at mobile resolution")
    material.set_shader_param("earth_texture", solid_texture(Color.black))
    material.set_shader_param("night_texture", solid_texture(Color.white))
    scene.call("ApplySunAppearance", 0.0)
    scene.call("ApplySunAngle", PI)
    yield(VisualServer, "frame_post_draw")
    var day = luminance(sample_color(capture(), Vector3(0.4, 0, 0)))
    scene.call("ApplySunAngle", 0.0)
    yield(VisualServer, "frame_post_draw")
    var gold = sample_color(capture(), Vector3(0.4, 0, 0))
    check(day < 0.01, "city emission is absent on the daylight hemisphere")
    check(luminance(gold) > day + 0.2, "city emission appears in full darkness")
    check(gold.r > gold.g and gold.g > gold.b, "night lights have a warm golden color")

    scene.call("ApplySunAngle", PI * 0.5)
    yield(VisualServer, "frame_post_draw")
    var half = capture("res://build/validation/city-mask-half.png")
    check(luminance(sample_color(half, Vector3(-0.65, 0, 0))) >
        luminance(sample_color(half, Vector3(0.65, 0, 0))) + 0.2,
        "night emission follows the moving terminator")
    var fade = []
    for incidence in [-0.22, -0.16, -0.11, -0.06, -0.01, 0.03]:
        scene.call("ApplySunAngle", acos(-incidence))
        yield(VisualServer, "frame_post_draw")
        fade.append(luminance(sample_color(capture(), Vector3.ZERO)))
    for index in range(1, fade.size()):
        check(fade[index] <= fade[index - 1] + 0.015, "city intensity fades monotonically through twilight")
        check(fade[index - 1] - fade[index] < 0.45, "city lights do not switch abruptly at the terminator")
    check(fade[0] > 0.2 and fade[-1] < 0.01, "twilight traverses fully lit cities to no emission")
    check(fade[2] > 0.02 and fade[2] < fade[0] - 0.02, "twilight includes intermediate city brightness")

    material.set_shader_param("earth_texture", original_day)
    material.set_shader_param("night_texture", original_night)
    scene.call("SetExpanded", true)
    scene.get_node("Tween").stop_all()
    scene.get_node("SunTween").stop_all()
    scene.call("ApplyEarthTransition", 1.0)
    scene.call("ApplySunAppearance", 0.0)
    scene.call("ApplySunAngle", 0.0)
    yield(VisualServer, "frame_post_draw")
    capture("res://docs/preview-city-night.png")

    # Find the real disc/limb contact to test the flare independently of timing.
    var core = scene.get_node("Sun/Core")
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
    var contact = (low + high) * 0.5
    scene.call("ApplySunTransition", contact)
    var flare = scene.get_node("Sun/Flare")
    check(flare.material_override.get_shader_param("strength") > 0.1, "focused flare activates at diamond contact")
    var energy = scene.get_node("Sun/SunLight").light_energy
    yield(VisualServer, "frame_post_draw")
    var with_flare = capture("res://docs/preview-city-diamond-flare.png")
    scene.set("SunFlareStrength", 0.0)
    scene.call("ApplySunTransition", contact)
    yield(VisualServer, "frame_post_draw")
    var no_flare = capture("res://build/validation/diamond-no-flare.png")
    var point = pixel_position(with_flare, core.global_transform.origin)
    var gain = 0.0
    var samples = 0
    with_flare.lock()
    no_flare.lock()
    for dy in range(-1, 2):
        for dx in range(65, 120):
            gain += luminance(with_flare.get_pixel(int(point.x) + dx, int(point.y) + dy)) - \
                luminance(no_flare.get_pixel(int(point.x) + dx, int(point.y) + dy))
            samples += 1
    with_flare.unlock()
    no_flare.unlock()
    check(gain / samples > 0.015, "a focused horizontal beam is rendered beyond the local halo")
    check(abs(scene.get_node("Sun/SunLight").light_energy - energy) < 0.0001,
        "flare opacity never changes physical sunlight energy")
    scene.set("SunFlareStrength", 0.75)
    scene.call("ApplySunTransition", 1.0)
    check(flare.material_override.get_shader_param("strength") < 0.001, "contact flare fades after the Sun leaves the limb")
    scene.call("ApplySunAngle", PI)
    check(flare.material_override.get_shader_param("strength") < 0.001, "flare stays hidden behind the camera")
    print("Twilight city luminance: ", fade, "; flare beam gain: ", gain / samples)
    if failures.empty():
        print("PASS: NASA night map, golden emission, smooth terminator fade, focused contact beam, stable irradiance")
    quit(0 if failures.empty() else 1)
