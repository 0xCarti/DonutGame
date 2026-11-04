shader_type spatial;
render_mode cull_disabled;
uniform vec4 oil_color : source_color = vec4(0.30, 0.17, 0.035, 1.0);
varying vec3 local_pos;
void vertex() {
    local_pos = VERTEX;
    VERTEX.y += sin(VERTEX.x * 10.0 + TIME * 1.8) * cos(VERTEX.z * 11.0 + TIME * 1.2) * 0.009;
}
void fragment() {
    float wave = sin(local_pos.x * 16.0 + TIME * 1.5) * cos(local_pos.z * 18.0 - TIME * 1.1);
    float glint = pow(max(0.0, wave), 12.0);
    vec2 ripple = vec2(cos(local_pos.x * 8.0 + TIME * 1.6) * sin(local_pos.z * 9.0 - TIME), sin(local_pos.x * 7.0 - TIME) * cos(local_pos.z * 10.0 + TIME * 1.2)) * 0.095;
    NORMAL_MAP = normalize(vec3(ripple, 1.0)) * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 0.45;
    ALBEDO = oil_color.rgb + vec3(0.14, 0.11, 0.025) * wave * 0.15;
    METALLIC = 0.20;
    ROUGHNESS = 0.22;
    EMISSION = vec3(0.45, 0.26, 0.07) * (0.02 + glint * 0.04);
}
