shader_type canvas_item;
// Umgebung der Streckenkarte (OSM-Netz, UV = Weltkoordinaten in Metern). Erkennt Flächen an ihrer Farbe:
// Rasen mit Mähstreifen, Wald/Bäume mit Blattstruktur, Wasser mit Wellen und Glitzern, Tribünen mit Zuschauern,
// alles andere mit leichter Körnung; darüber ziehen weiche Wolkenschatten. anim = 0 hält alles still.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float anim = 1.0;
uniform float px_per_m = 1.0;

varying vec2 wpos;

void vertex() {
	wpos = UV;
}

void fragment() {
	vec4 base = COLOR;
	vec3 c = base.rgb;
	vec2 w = wpos;
	float t = TIME * anim;
	float n1 = texture(noise_tex, w / 140.0).r;
	float n2 = texture(noise_tex, w / 11.0).r;
	float near = smoothstep(0.35, 1.4, px_per_m);
	vec3 col = c;
	bool water = c.b > c.r + 0.2 && c.b > c.g + 0.04;
	bool green = c.g > c.r + 0.05 && c.g > c.b + 0.08;
	bool stand = c.b - c.r > 0.07 && c.b - c.r < 0.17 && c.r > 0.64 && c.r < 0.84;
	if (water) {
		float wv = texture(noise_tex, w / 70.0 + vec2(t * 0.012, t * 0.007)).r
			+ texture(noise_tex, w / 38.0 - vec2(t * 0.009, -t * 0.013)).r;
		col *= 0.9 + 0.12 * wv + 0.06 * (n1 - 0.5);
		col += vec3(0.35) * smoothstep(1.42, 1.62, wv) * near;
	} else if (green) {
		if (c.g < 0.7) {
			// Wald und Baumkronen
			col *= 0.84 + 0.32 * n2;
		} else {
			// Rasen und Felder: Mähstreifen nur nah, Körnung und große Flecken immer
			// Richtung wechselt fleckenweise (wie verschieden gemähte Wiesen)
			float a = floor(texture(noise_tex, w / 520.0).r * 4.0) * 0.7854;
			float stripe = step(0.5, fract(dot(w, vec2(cos(a), sin(a))) / 18.0));
			col *= 0.965 + 0.045 * stripe * near + 0.10 * (n2 - 0.5) + 0.12 * (n1 - 0.5);
		}
	} else if (stand) {
		// Tribüne: bunte Zuschauer in Reihen (nur nah)
		vec2 cell = floor(w / vec2(0.9, 1.3));
		float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		vec3 crowd = 0.74 + 0.26 * cos(6.2831 * (h + vec3(0.0, 0.33, 0.67)));
		float seat = step(0.3, fract(h * 7.13));
		col = mix(c * 0.9, crowd, seat * 0.55 * smoothstep(0.5, 1.5, px_per_m));
	} else {
		col *= 0.985 + 0.03 * (n2 - 0.5) + 0.04 * (n1 - 0.5);
	}
	// Wolkenschatten
	float cl = texture(noise_tex, w / 900.0 + vec2(t * 0.0035, t * 0.0018)).r;
	col *= 1.0 - 0.11 * smoothstep(0.52, 0.78, cl);
	COLOR = vec4(col, base.a);
}
