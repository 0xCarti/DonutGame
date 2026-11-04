shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// All movement comes from the simulation clock. Pausing the stand freezes fire,
// smoke and sparks instead of leaving an independent shader animation running.
uniform float simulation_time = 0.0;
uniform float seed = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float movement : hint_range(0.0, 1.0) = 1.0;
uniform int effect_type = 0; // 0 flame sheet, 1 soft smoke, 2 ember

float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 19.19);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float turbulence(vec2 p) {
	return noise(p) * 0.57 + noise(p * 2.07 + 7.3) * 0.29
		+ noise(p * 4.13 + 19.7) * 0.14;
}

void vertex() {
	if (effect_type == 0) {
		float h = UV.y;
		float sway = sin(UV.x * 18.0 + simulation_time * 2.7 + seed * 9.1)
			+ sin(UV.x * 31.0 - simulation_time * 1.8 + seed * 3.0) * 0.45;
		VERTEX.x += sway * h * h * 0.055 * movement;
		VERTEX.z += sin(UV.x * 12.0 + simulation_time * 1.1 + seed) * h * 0.075 * movement;
	}
}

void fragment() {
	vec2 uv = UV;
	float t = simulation_time;
	if (effect_type == 0) {
		float h = uv.y;
		vec2 p = vec2(uv.x * 7.2 + seed * 3.7, h * 3.2 - t * 1.7);
		vec2 curl = vec2(turbulence(p * 0.68 + vec2(0.0, -t * 0.25)),
			turbulence(p * 0.91 + 11.0));
		float n = turbulence(p + (curl - 0.5) * 2.9);
		float small = noise(p * 5.6 + vec2(t * 0.2, -t * 1.4));
		// A connected hot base breaks into irregular climbing tongues above it.
		// Soft coverage replaces any silhouette from the rectangular geometry.
		float fuel = (1.0 - h) * 0.91 + (n - 0.5) * 1.05;
		float tongue = smoothstep(0.28, 0.50, fuel);
		float edge = smoothstep(0.0, 0.075, uv.x) * smoothstep(0.0, 0.075, 1.0 - uv.x);
		edge *= smoothstep(0.0, 0.026, h) * (1.0 - smoothstep(0.82, 1.0, h));
		float density = tongue * edge * (0.75 + 0.25 * small);
		float hot = clamp((1.0 - h) * 0.95 + (n - 0.5) * 0.40, 0.0, 1.0);
		vec3 color = mix(vec3(0.80, 0.075, 0.012), vec3(1.0, 0.45, 0.035), smoothstep(0.12, 0.60, hot));
		color = mix(color, vec3(1.0, 0.91, 0.43), smoothstep(0.62, 0.96, hot));
		color = mix(color, vec3(1.0, 0.98, 0.78), smoothstep(0.90, 1.0, hot) * 0.65);
		ALBEDO = color;
		EMISSION = color * (0.22 + 0.30 * hot);
		ALPHA = density * opacity;
	} else if (effect_type == 1) {
		vec2 centered = uv * 2.0 - 1.0;
		float billow = turbulence(uv * 4.3 + vec2(seed * 5.1, -t * 0.20));
		float radial = 1.0 - smoothstep(0.20, 1.0, length(centered) + (billow - 0.5) * 0.4);
		ALBEDO = mix(vec3(0.13, 0.115, 0.10), vec3(0.25, 0.23, 0.21), billow);
		ALPHA = radial * (0.32 + 0.68 * billow) * opacity;
	} else {
		vec2 centered = uv * 2.0 - 1.0;
		float core = 1.0 - smoothstep(0.0, 0.65, length(centered));
		float halo = 1.0 - smoothstep(0.0, 1.0, length(centered));
		vec3 color = mix(vec3(1.0, 0.22, 0.02), vec3(1.0, 0.94, 0.60), core);
		ALBEDO = color;
		EMISSION = color * 0.65;
		ALPHA = halo * opacity;
	}
}
