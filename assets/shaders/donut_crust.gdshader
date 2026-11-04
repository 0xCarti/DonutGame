shader_type spatial;
uniform vec4 baked_color : source_color = vec4(0.78, 0.46, 0.19, 1.0);
float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
    float tube = sin(UV.y * 6.2831853);
    float seam = exp(-tube * tube * 32.0);
    float mottling = grain(floor(UV * vec2(100.0, 48.0)));
    float toast = 0.94 + 0.06 * sin(UV.x * 19.0 + sin(UV.x * 37.0) * 0.4);
    ALBEDO = baked_color.rgb * toast * (0.97 + mottling * 0.055);
    ALBEDO += vec3(0.12, 0.075, 0.018) * seam;
    ROUGHNESS = 0.68 + mottling * 0.16;
    METALLIC = 0.0;
    SPECULAR = 0.28;
}
