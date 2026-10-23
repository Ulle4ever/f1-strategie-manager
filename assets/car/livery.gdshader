shader_type spatial;
// Lackierung in Teamfarben: helle, graue Lackflächen der Vorlage werden zur Hauptfarbe, rote Akzente zur Zweitfarbe;
// Dunkles (Reifen, Carbon, Cockpit) bleibt. Die Helligkeit der Vorlage bleibt als Schattierung erhalten.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 primary : source_color = vec3(0.9, 0.1, 0.1);
uniform vec3 secondary : source_color = vec3(1.0);

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float accent = smoothstep(0.35, 0.6, sat) * step(c.g, c.r) * smoothstep(0.15, 0.35, mx);
	float paint = smoothstep(0.22, 0.5, lum) * (1.0 - smoothstep(0.18, 0.4, sat));
	vec3 col = mix(c, primary * clamp(lum / 0.82, 0.25, 1.15), paint);
	col = mix(col, secondary * clamp(mx / 0.9, 0.3, 1.1), accent);
	float glossy = max(paint, accent);
	ALBEDO = col;
	ROUGHNESS = mix(0.75, 0.28, glossy);
	METALLIC = mix(0.0, 0.2, glossy);
	SPECULAR = 0.5;
}
