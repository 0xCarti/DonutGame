shader_type spatial;
void fragment() {
    float top = sin(UV.y * 6.2831853);
    if (top < 0.06) { discard; }
    float grain = fract(sin(dot(floor(UV * vec2(150.0, 55.0)), vec2(12.9898, 78.233))) * 43758.5453);
    if (top < 0.26 && grain < 0.30) { discard; }
    ALBEDO = vec3(0.91, 0.86, 0.75) * (0.95 + grain * 0.05);
    ROUGHNESS = 0.98;
    SPECULAR = 0.12;
}
