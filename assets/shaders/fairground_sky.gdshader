shader_type sky;

void sky() {
    // Original hand-tuned dusk gradient. A warm band at the far treeline
    // balances the cool zenith and supplies colored reflections to the steel.
    float altitude = clamp(EYEDIR.y, -0.35, 1.0);
    vec3 horizon = vec3(0.105, 0.115, 0.16);
    vec3 zenith = vec3(0.025, 0.045, 0.090);
    vec3 dusk = mix(horizon, zenith, smoothstep(-0.05, 0.70, altitude));
    float west = pow(max(0.0, dot(normalize(vec3(-0.7, 0.02, -1.0)), EYEDIR)), 7.0);
    dusk += vec3(0.12, 0.065, 0.026) * west * exp(-abs(altitude) * 7.0);
    COLOR = dusk;
}
