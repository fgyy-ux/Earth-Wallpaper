using Godot;

/// <summary>Godot 3.5.3 Mono portrait Earth scene.</summary>
public class EarthWallpaper : Spatial
{
    [Export] public Vector3 MinimizedPosition = new Vector3(-1.35f, 1.15f, 0.0f);
    // Keep the center beyond the left edge so only the globe's right side shows.
    [Export] public Vector3 ExpandedPosition = new Vector3(-4.25f, 0.0f, 0.0f);
    [Export] public float MinimizedScale = 0.65f;
    [Export] public float ExpandedScale = 4.5f;
    [Export] public float TransitionSeconds = 0.5f;
    [Export] public float ExpansionSeconds = 0.8f;
    [Export] public float ExpansionRightwardOffset = 0.45f;
    [Export] public float ExpansionTurnDegrees = 8.0f;
    [Export] public float RotationDegreesPerSecond = 12.0f;
    [Export] public float SunRevealSeconds = 7.2f;
    [Export] public float SunOrbitDegreesPerSecond = 8.0f;
    [Export] public float SunDistance = 1000.0f;
    // A small, fixed display radius; never expand the disc to Earth's radius.
    [Export] public float SunRadius = 0.12f;
    [Export] public float SunLightEnergy = 1.1f;
    [Export] public float SunHaloStrength = 0.5f;
    [Export] public float EclipseHaloStrength = 0.65f;
    [Export] public float SunFlareStrength = 0.75f;
    [Export] public float CityLightsStrength = 0.85f;
    // Normal-dot-light width, measured from the terminator into the night side.
    [Export] public float NightTwilightWidth = 0.18f;
    [Export] public float MaximumTapMovement = 24.0f;
    [Export] public int MaximumTapMilliseconds = 350;

    private Spatial _earthRoot;
    private Spatial _spin;
    private Tween _tween;
    private Camera _camera;
    private Spatial _sun;
    private MeshInstance _sunMesh;
    private MeshInstance _sunCorona;
    private MeshInstance _eclipseRing;
    private MeshInstance _sunFlare;
    private DirectionalLight _sunLight;
    private ShaderMaterial _coreMaterial;
    private ShaderMaterial _coronaMaterial;
    private ShaderMaterial _eclipseMaterial;
    private ShaderMaterial _flareMaterial;
    private ShaderMaterial _earthMaterial;
    private Tween _sunTween;
    private float _sunAppearance;
    // Side lighting shows a half-lit disc in the initial compact layout.
    private float _sunAngle = Mathf.Pi * 0.5f;
    private float _sunStartAngle;
    private float _sunBehindAngle;
    private float _sunTargetAngle;
    private float _sunStartAppearance;
    private float _sunDiscVisibility;
    private float _sunStartDiscVisibility;
    private float _orbitBlend;
    private const float SunRingArrivalFraction = 0.22f;
    private const float SunRingHoldFraction = 0.40f;
    private int _touchIndex = -1;
    private bool _mousePending;
    private Vector2 _pressPosition;
    private ulong _pressTime;
    private bool _moved;
    private bool _expanded;
    private Basis _initialSpinBasis;
    private Vector3 _spinOrigin;
    private float _idleYaw;
    private float _gestureYaw;
    private Vector3 _moveStart;
    private Vector3 _moveTarget;
    private Vector3 _moveWaypoint;
    private float _scaleStart;
    private float _scaleTarget;
    private float _turnStart;

    public bool Expanded { get { return _expanded; } }

    public override void _Ready()
    {
        _earthRoot = GetNode<Spatial>("EarthRoot");
        _spin = GetNode<Spatial>("EarthRoot/Spin");
        _tween = GetNode<Tween>("Tween");
        _camera = GetNode<Camera>("Camera");
        _sun = GetNode<Spatial>("Sun");
        _sunMesh = GetNode<MeshInstance>("Sun/Core");
        _sunCorona = GetNode<MeshInstance>("Sun/Corona");
        _eclipseRing = GetNode<MeshInstance>("EclipseRing");
        _sunFlare = GetNode<MeshInstance>("Sun/Flare");
        _sunLight = GetNode<DirectionalLight>("Sun/SunLight");
        _sunTween = GetNode<Tween>("SunTween");
        // Each scene instance owns its reveal opacity.
        _coronaMaterial = (ShaderMaterial)_sunCorona.MaterialOverride.Duplicate();
        _sunCorona.MaterialOverride = _coronaMaterial;
        _coreMaterial = (ShaderMaterial)_sunMesh.Mesh.SurfaceGetMaterial(0).Duplicate();
        _sunMesh.MaterialOverride = _coreMaterial;
        _eclipseMaterial = (ShaderMaterial)_eclipseRing.MaterialOverride.Duplicate();
        _eclipseRing.MaterialOverride = _eclipseMaterial;
        _flareMaterial = (ShaderMaterial)_sunFlare.MaterialOverride.Duplicate();
        _sunFlare.MaterialOverride = _flareMaterial;
        MeshInstance earthMesh = GetNode<MeshInstance>("EarthRoot/Spin/EarthMesh");
        _earthMaterial = (ShaderMaterial)(earthMesh.MaterialOverride ?? earthMesh.Mesh.SurfaceGetMaterial(0)).Duplicate();
        earthMesh.MaterialOverride = _earthMaterial;
        _camera.MakeCurrent();
        // Only configure clipping here; neither orbit nor approach moves Camera.
        _camera.Far = Mathf.Max(_camera.Far, Mathf.Max(100.0f, SunDistance) * 1.2f);
        _initialSpinBasis = _spin.Transform.basis.Orthonormalized();
        _spinOrigin = _spin.Translation;

        _earthRoot.Translation = MinimizedPosition;
        _earthRoot.Scale = Vector3.One * Mathf.Max(0.01f, MinimizedScale);
        UpdateSunVisuals();
    }

    public override void _Process(float delta)
    {
        // Clockwise viewed from above (+Y toward the origin).
        _idleYaw = Mathf.PosMod(_idleYaw -
            Mathf.Deg2Rad(RotationDegreesPerSecond) * delta, Mathf.Pi * 2.0f);
        UpdateSpin();
        if (_expanded && !_sunTween.IsActive() && _sunAppearance >= 0.999f)
        {
            _orbitBlend = Mathf.Min(1.0f, _orbitBlend + delta / 0.7f);
            _sunAngle = Mathf.PosMod(_sunAngle +
                Mathf.Deg2Rad(SunOrbitDegreesPerSecond) * delta *
                Mathf.SmoothStep(0.0f, 1.0f, _orbitBlend), Mathf.Pi * 2.0f);
        }
        else
            _orbitBlend = 0.0f;
        UpdateSunVisuals();
    }

    // A tap can begin anywhere in the scene, including the empty background.
    // UI controls can still consume their own input before this callback.
    public override void _UnhandledInput(InputEvent inputEvent)
    {
        if (inputEvent is InputEventScreenTouch touchPress &&
            touchPress.Pressed && touchPress.Index == 0 && CanBeginTap())
        {
            _touchIndex = touchPress.Index;
            BeginTap(touchPress.Position);
            GetViewport().SetInputAsHandled();
        }
        else if (inputEvent is InputEventMouseButton mousePress &&
            mousePress.Pressed && mousePress.ButtonIndex == (int)ButtonList.Left &&
            CanBeginTap())
        {
            _mousePending = true;
            BeginTap(mousePress.Position);
            GetViewport().SetInputAsHandled();
        }
        else if (inputEvent is InputEventScreenDrag drag &&
            drag.Index == _touchIndex)
        {
            CheckMovement(drag.Position);
        }
        else if (inputEvent is InputEventScreenTouch touch &&
            !touch.Pressed && touch.Index == _touchIndex)
        {
            _touchIndex = -1;
            FinishTap(touch.Position);
        }
        else if (_mousePending && inputEvent is InputEventMouseMotion motion)
        {
            CheckMovement(motion.Position);
        }
        else if (_mousePending && inputEvent is InputEventMouseButton mouse &&
            !mouse.Pressed && mouse.ButtonIndex == (int)ButtonList.Left)
        {
            _mousePending = false;
            FinishTap(mouse.Position);
        }
    }

    private bool CanBeginTap()
    {
        return !_tween.IsActive() && _touchIndex == -1 && !_mousePending;
    }

    private void BeginTap(Vector2 position)
    {
        _pressPosition = position;
        _pressTime = OS.GetTicksMsec();
        _moved = false;
    }

    private void CheckMovement(Vector2 position)
    {
        if (position.DistanceTo(_pressPosition) > MaximumTapMovement)
            _moved = true;
    }

    private void FinishTap(Vector2 position)
    {
        CheckMovement(position);
        if (_moved ||
            OS.GetTicksMsec() - _pressTime > (ulong)Mathf.Max(1, MaximumTapMilliseconds) ||
            _tween.IsActive())
            return;

        GetViewport().SetInputAsHandled();
        SetExpanded(!_expanded);
    }

    public void SetExpanded(bool expanded)
    {
        if (_tween.IsActive() || expanded == _expanded)
            return;

        _expanded = expanded;
        _moveStart = _earthRoot.Translation;
        _moveTarget = expanded ? ExpandedPosition : MinimizedPosition;
        _scaleStart = _earthRoot.Scale.x;
        _scaleTarget = Mathf.Max(0.01f,
            expanded ? ExpandedScale : MinimizedScale);
        _turnStart = Mathf.PosMod(_gestureYaw, Mathf.Pi * 2.0f);
        _moveWaypoint = _moveStart +
            Vector3.Right * Mathf.Max(0.0f, ExpansionRightwardOffset);
        _moveWaypoint.y = Mathf.Lerp(_moveStart.y, _moveTarget.y, 0.2f);
        _moveWaypoint.z = Mathf.Lerp(_moveStart.z, _moveTarget.z, 0.2f);
        float duration = Mathf.Max(0.01f,
            expanded ? ExpansionSeconds : TransitionSeconds);

        _tween.StopAll();
        _tween.RemoveAll();
        // One track owns the complete Earth pose. Two delayed property tracks
        // on the same transform can overwrite one another at their boundary.
        _tween.InterpolateMethod(this, nameof(ApplyEarthTransition),
            0.0f, 1.0f, duration, Tween.TransitionType.Linear, Tween.EaseType.InOut);
        _tween.Start();
        AnimateSun(expanded, duration);
    }

    public void ApplyEarthTransition(float progress)
    {
        float t = Mathf.Clamp(progress, 0.0f, 1.0f);
        float firstLeg = Mathf.SmoothStep(0.0f, 1.0f, Mathf.Clamp(t / 0.35f, 0.0f, 1.0f));
        if (_expanded)
        {
            _earthRoot.Translation = t < 0.35f
                ? _moveStart.LinearInterpolate(_moveWaypoint, firstLeg)
                : _moveWaypoint.LinearInterpolate(_moveTarget,
                    Mathf.SmoothStep(0.0f, 1.0f, (t - 0.35f) / 0.65f));
            _gestureYaw = _turnStart -
                Mathf.Deg2Rad(Mathf.Max(0.0f, ExpansionTurnDegrees)) * firstLeg;
        }
        else
        {
            _earthRoot.Translation = _moveStart.LinearInterpolate(_moveTarget,
                Mathf.SmoothStep(0.0f, 1.0f, t));
        }
        _earthRoot.Scale = Vector3.One * Mathf.Lerp(_scaleStart, _scaleTarget,
            Mathf.SmoothStep(0.0f, 1.0f, t));
        UpdateSpin();
        UpdateSunVisuals();
    }

    private void UpdateSpin()
    {
        // Rebuild a unit rotation from angles instead of repeatedly modifying
        // a scaled basis. This prevents accumulated shear/scale distortion.
        _spin.Transform = new Transform(
            new Basis(Vector3.Up, _idleYaw + _gestureYaw) * _initialSpinBasis,
            _spinOrigin);
    }

    private void AnimateSun(bool expanded, float earthDuration)
    {
        _sunTween.StopAll();
        _sunTween.RemoveAll();
        float duration = expanded ? Mathf.Max(earthDuration, SunRevealSeconds) : earthDuration;
        _sunStartAngle = _sunAngle;
        _sunBehindAngle = NearestAngle(_sunAngle, 0.0f);
        _sunTargetAngle = NearestAngle(expanded ? _sunBehindAngle : _sunAngle, Mathf.Pi * 0.5f);
        _sunStartAppearance = _sunAppearance;
        _sunStartDiscVisibility = _sunDiscVisibility;
        _sunTween.InterpolateMethod(this, nameof(ApplySunTransition),
            0.0f, 1.0f, duration, Tween.TransitionType.Linear, Tween.EaseType.InOut);
        _sunTween.Start();
    }

    public void ApplySunTransition(float progress)
    {
        float t = Mathf.Clamp(progress, 0.0f, 1.0f);
        if (_expanded)
        {
            // Arrive behind Earth, hold the eclipse ring, then emerge right.
            // One track owns the angle, including when a reveal is interrupted.
            if (t < SunRingArrivalFraction)
                _sunAngle = Mathf.Lerp(_sunStartAngle, _sunBehindAngle,
                    Mathf.SmoothStep(0.0f, 1.0f, t / SunRingArrivalFraction));
            else if (t < SunRingHoldFraction)
                _sunAngle = _sunBehindAngle;
            else
                _sunAngle = Mathf.Lerp(_sunBehindAngle, _sunTargetAngle,
                    Mathf.SmoothStep(0.0f, 1.0f,
                        (t - SunRingHoldFraction) / (1.0f - SunRingHoldFraction)));
            _sunAppearance = Mathf.Lerp(_sunStartAppearance, 1.0f, t);
            // Hide the incoming display pass. Fade in while the small disc is
            // still occulted, so its first visible sliver forms the diamond.
            _sunDiscVisibility = t < SunRingHoldFraction
                ? Mathf.Lerp(_sunStartDiscVisibility, 0.0f,
                    Mathf.SmoothStep(0.0f, 1.0f, Mathf.Clamp(t / SunRingArrivalFraction, 0.0f, 1.0f)))
                : Mathf.SmoothStep(0.0f, 1.0f,
                    Mathf.Clamp((t - SunRingHoldFraction) / 0.08f, 0.0f, 1.0f));
        }
        else
        {
            float eased = Mathf.SmoothStep(0.0f, 1.0f, t);
            _sunAngle = Mathf.Lerp(_sunStartAngle, _sunTargetAngle, eased);
            _sunAppearance = Mathf.Lerp(_sunStartAppearance, 0.0f, eased);
            _sunDiscVisibility = Mathf.Lerp(_sunStartDiscVisibility, 0.0f, eased);
        }
        UpdateSunVisuals();
    }

    private static float NearestAngle(float current, float target)
    {
        return current + Mathf.Atan2(Mathf.Sin(target - current), Mathf.Cos(target - current));
    }

    public void ApplySunAppearance(float appearance)
    {
        _sunAppearance = Mathf.Clamp(appearance, 0.0f, 1.0f);
        _sunDiscVisibility = _sunAppearance;
        UpdateSunVisuals();
    }

    public void ApplySunAngle(float radians)
    {
        _sunAngle = radians;
        UpdateSunVisuals();
    }

    private void UpdateSunVisuals()
    {
        float earthRadius = Mathf.Max(0.01f, _earthRoot.Scale.x);
        float sunRadius = Mathf.Clamp(SunRadius, 0.015f, _camera.Size * 0.02f);
        float orbitRadius = Mathf.Max(100.0f, SunDistance);
        float tilt = Mathf.Deg2Rad(15.0f);
        Basis cameraBasis = _camera.GlobalTransform.basis.Orthonormalized();
        Vector3 towardSun = cameraBasis.Xform(new Vector3(
            Mathf.Sin(_sunAngle) * Mathf.Cos(tilt),
            Mathf.Sin(_sunAngle) * Mathf.Sin(tilt),
            -Mathf.Cos(_sunAngle))).Normalized();
        Vector3 earthCenter = _earthRoot.GlobalTransform.origin;
        _sun.GlobalTransform = new Transform(Basis.Identity,
            earthCenter + towardSun * orbitRadius);

        // Orthographic sky display, independent of the physical light marker.
        // Compress only the lateral sky path; retain the physical orbit depth.
        // This is a cinematic sky projection, not astronomical scene geometry.
        float displayOrbit = earthRadius + _camera.Size * 0.65f;
        float sine = Mathf.Sin(_sunAngle);
        float displayPhase = Mathf.Abs(sine);
        // Reach the limb early, ease through contact, and spend most of the
        // visible passage crossing the sky rather than racing out of frame.
        float displayTravel = displayPhase < 0.2f
            ? earthRadius * Mathf.SmoothStep(0.0f, 1.0f, displayPhase / 0.2f)
            : Mathf.Lerp(earthRadius, displayOrbit,
                Mathf.SmoothStep(0.0f, 1.0f, (displayPhase - 0.2f) / 0.8f));
        float lateralOffset = displayTravel * (sine < 0.0f ? -1.0f : 1.0f);
        Vector3 displayDirection = new Vector3(Mathf.Cos(tilt), Mathf.Sin(tilt), 0.0f);
        Vector3 displayCenter = earthCenter + cameraBasis.Xform(
            displayDirection * lateralOffset + Vector3.Forward * (Mathf.Cos(_sunAngle) * orbitRadius));
        float haloRadius = sunRadius * 3.5f;
        Vector3 inCamera = _camera.GlobalTransform.AffineInverse().Xform(displayCenter);
        float halfWidth = _camera.Size * 0.5f;
        float edgeFade = Mathf.SmoothStep(-halfWidth - haloRadius,
            -halfWidth + _camera.Size * 0.2f, inCamera.x) *
            (1.0f - Mathf.SmoothStep(halfWidth - _camera.Size * 0.2f,
                halfWidth + haloRadius, inCamera.x));
        // After the right-hand exit the orbit advances toward +camera Z, behind
        // the viewer. Do not project that half of the orbit back onto Earth.
        float cameraFade = 1.0f - Mathf.SmoothStep(-_camera.Near - haloRadius,
            -_camera.Near, inCamera.z);
        float discVisibility = _sunDiscVisibility * edgeFade * cameraFade;
        _sunMesh.Visible = discVisibility > 0.001f;
        _sunMesh.GlobalTransform = new Transform(Basis.Identity.Scaled(Vector3.One * sunRadius), displayCenter);
        _coreMaterial.SetShaderParam("visibility", discVisibility);
        _sunCorona.GlobalTransform = new Transform(
            cameraBasis.Scaled(Vector3.One * haloRadius), displayCenter);
        _coronaMaterial.SetShaderParam("strength", discVisibility * Mathf.Clamp(SunHaloStrength, 0.0f, 1.0f));

        // Keep the annular halo centered on Earth. It never travels as a giant
        // luminous disc. Depth testing hides its inner part behind the globe.
        float nearLimb = 1.0f - Mathf.SmoothStep(earthRadius + sunRadius * 3.0f,
            earthRadius + _camera.Size * 0.22f, Mathf.Abs(lateralOffset));
        float eclipse = Mathf.SmoothStep(0.0f, 0.2f, Mathf.Cos(_sunAngle));
        float ringVisibility = Mathf.SmoothStep(0.0f, 0.16f, _sunAppearance) * nearLimb * eclipse;
        float contact = (Mathf.Abs(lateralOffset) - earthRadius) / Mathf.Max(0.1f, sunRadius * 2.0f);
        _eclipseRing.GlobalTransform = new Transform(
            cameraBasis.Scaled(Vector3.One * earthRadius * 1.13f),
            earthCenter + cameraBasis.Xform(Vector3.Forward * orbitRadius));
        _eclipseMaterial.SetShaderParam("strength", ringVisibility * Mathf.Clamp(EclipseHaloStrength, 0.0f, 1.0f));
        _eclipseMaterial.SetShaderParam("bead_strength", Mathf.Exp(-contact * contact) * discVisibility);
        _eclipseMaterial.SetShaderParam("bead_direction", new Vector2(
            Mathf.Cos(tilt), Mathf.Sin(tilt)) * (lateralOffset < 0.0f ? -1.0f : 1.0f));

        // A narrow anamorphic streak appears only as the disc clears the limb.
        // The opaque planet still occludes the beam. Its alpha never feeds
        // back into the DirectionalLight energy, exposure, or city-light mask.
        float exposed = Mathf.SmoothStep(earthRadius - sunRadius,
            earthRadius + sunRadius * 0.25f, Mathf.Abs(lateralOffset));
        float flare = Mathf.Exp(-contact * contact) * exposed * discVisibility * eclipse;
        _sunFlare.GlobalTransform = new Transform(
            cameraBasis.Scaled(new Vector3(_camera.Size * 0.23f, _camera.Size * 0.025f, 1.0f)),
            displayCenter);
        _flareMaterial.SetShaderParam("strength", flare * Mathf.Clamp(SunFlareStrength, 0.0f, 1.0f));

        // World-space sunlight also drives the emissive night texture. The
        // shader transforms each fragment normal to world space, so this mask
        // follows spin, the camera, and the orbit without resetting geography.
        _earthMaterial.SetShaderParam("sun_direction_world", towardSun);
        _earthMaterial.SetShaderParam("city_lights_strength", Mathf.Clamp(CityLightsStrength, 0.0f, 2.0f));
        _earthMaterial.SetShaderParam("night_twilight_width", Mathf.Clamp(NightTwilightWidth, 0.02f, 0.4f));

        // Godot 3 lights shine along local -Z. Aim the distant DirectionalLight
        // from the Sun toward Earth: its parallel rays have no range/falloff.
        // Never LookAt() or translate Earth/Spin/Camera to follow the Sun.
        _sunLight.LookAt(earthCenter, cameraBasis.y);
        _sunLight.LightEnergy = Mathf.Max(0.0f, SunLightEnergy);
    }
}
