extends SceneTree

var failures = []
var scene
var globe
var spin
var tween
var press_position = Vector2(198, 502)

func _init():
    call_deferred("_run")

func check(condition, description):
    if not condition:
        failures.append(description)
        printerr("FAIL: " + description)

func wait_seconds(seconds):
    yield(create_timer(seconds), "timeout")

func send_input(event):
    Input.parse_input_event(event)
    get_root().input(event)
    get_root().unhandled_input(event)

func touch_begin():
    var event = InputEventScreenTouch.new()
    event.index = 0
    event.pressed = true
    event.position = press_position
    send_input(event)
    yield(self, "physics_frame")
    yield(self, "physics_frame")

func touch_end(position):
    var event = InputEventScreenTouch.new()
    event.index = 0
    event.pressed = false
    event.position = position
    send_input(event)

func save_preview(path):
    var image = get_root().get_texture().get_data()
    image.flip_y()
    image.save_png(path)

func _run():
    var packed = load("res://scenes/EarthWallpaper.tscn")
    check(packed != null, "scene loads")
    if packed == null:
        quit(1)
        return
    scene = packed.instance()
    get_root().size = Vector2(720, 1280)
    get_root().add_child(scene)
    globe = scene.get_node("EarthRoot")
    spin = scene.get_node("EarthRoot/Spin")
    tween = scene.get_node("Tween")
    press_position = scene.get_node("Camera").unproject_position(globe.global_transform.origin)

    check(globe.translation.distance_to(Vector3(-1.35, 1.15, 0)) < 0.001, "initial upper-left position")
    check(globe.scale.distance_to(Vector3.ONE * 0.65) < 0.001, "initial compact scale")
    var initial_basis = spin.transform.basis
    yield(wait_seconds(0.35), "completed")
    check(not spin.transform.basis.is_equal_approx(initial_basis), "rotation advances")
    save_preview("res://docs/preview-minimized.png")

    yield(touch_begin(), "completed")
    var transition_start_position = globe.translation
    var transition_start_basis = spin.transform.basis
    touch_end(press_position)
    yield(wait_seconds(0.1), "completed")
    check(globe.translation.x > transition_start_position.x + 0.02, "expansion first moves the globe slightly right")
    check(spin.transform.basis.x.angle_to(transition_start_basis.x) > deg2rad(2.0), "rightward move includes an extra gentle turn")
    save_preview("res://docs/preview-transition-right.png")
    yield(wait_seconds(0.5), "completed")
    check(tween.is_active(), "expansion is slower than the previous half-second transition")
    yield(wait_seconds(0.35), "completed")
    var camera = scene.get_node("Camera")
    var expanded_center = camera.unproject_position(globe.global_transform.origin)
    var expanded_right = camera.unproject_position(globe.global_transform.origin + Vector3.RIGHT * globe.scale.x)
    var expanded_top = camera.unproject_position(globe.global_transform.origin + Vector3.UP * globe.scale.y)
    var expanded_bottom = camera.unproject_position(globe.global_transform.origin - Vector3.UP * globe.scale.y)
    var viewport_size = get_root().get_visible_rect().size
    check(not tween.is_active(), "expansion tween finishes")
    check(globe.translation.distance_to(Vector3(-4.25, 0, 0)) < 0.001, "rightward move settles at the vertically centered cropped position")
    check(globe.scale.distance_to(Vector3.ONE * 4.5) < 0.001, "expansion retains the original close-up size")
    check(expanded_center.x < 0, "expanded center is off screen so only the right side shows")
    check(abs(expanded_center.y - viewport_size.y * 0.5) < 1.0, "expanded Earth is vertically centered on screen")
    check(expanded_right.x > viewport_size.x * 0.45 and expanded_right.x < viewport_size.x * 0.60, "expanded right edge reaches roughly halfway across screen")
    check(expanded_bottom.y - expanded_top.y > viewport_size.y * 0.75, "expanded globe occupies most of the portrait height")
    save_preview("res://docs/preview-expanded.png")

    # The expanded center is off screen. Click the visible right-hand side.
    press_position = Vector2(viewport_size.x * 0.2, expanded_center.y)
    var mouse = InputEventMouseButton.new()
    mouse.button_index = BUTTON_LEFT
    mouse.position = press_position
    mouse.pressed = true
    send_input(mouse)
    yield(self, "physics_frame")
    yield(self, "physics_frame")
    mouse = InputEventMouseButton.new()
    mouse.button_index = BUTTON_LEFT
    mouse.position = press_position
    mouse.pressed = false
    send_input(mouse)
    yield(wait_seconds(0.65), "completed")
    check(globe.scale.distance_to(Vector3.ONE * 0.65) < 0.001, "mouse tap minimizes")

    # Background gestures obey the same swipe and long-press filtering.
    press_position = Vector2(680, 1000)
    yield(touch_begin(), "completed")
    var drag = InputEventScreenDrag.new()
    drag.index = 0
    drag.position = press_position + Vector2(100, 0)
    send_input(drag)
    touch_end(press_position)
    yield(wait_seconds(0.65), "completed")
    check(globe.scale.distance_to(Vector3.ONE * 0.65) < 0.001, "swipe does not toggle")

    yield(touch_begin(), "completed")
    yield(wait_seconds(0.4), "completed")
    touch_end(press_position)
    yield(wait_seconds(0.65), "completed")
    check(globe.scale.distance_to(Vector3.ONE * 0.65) < 0.001, "long press does not toggle")

    yield(touch_begin(), "completed")
    touch_end(press_position)
    yield(wait_seconds(0.95), "completed")
    check(globe.scale.distance_to(Vector3.ONE * 4.5) < 0.001, "one background tap expands")
    check(globe.translation.distance_to(Vector3(-4.25, 0, 0)) < 0.001, "background tap reaches the vertically centered cropped position")

    yield(touch_begin(), "completed")
    touch_end(press_position)
    yield(wait_seconds(0.65), "completed")
    check(globe.scale.distance_to(Vector3.ONE * 0.65) < 0.001, "next background tap minimizes")
    check(globe.translation.distance_to(Vector3(-1.35, 1.15, 0)) < 0.001, "background tap restores the compact position")

    if failures.empty():
        print("PASS: rightward move and turn, final framing, single taps on globe/background, mouse, and swipe/hold rejection")
    quit(0 if failures.empty() else 1)
