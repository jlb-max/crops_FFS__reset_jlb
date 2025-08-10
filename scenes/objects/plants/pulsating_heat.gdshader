// pulsating_heat.gdshader
shader_type canvas_item;
render_mode blend_mix;

// Textures d'entrée
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : source_color, filter_linear_mipmap; // Réutilise ta texture de bruit

// Paramètres de l'effet
uniform float strength : hint_range(0.0, 0.1) = 0.01;      // Force générale de la distorsion
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;    // Vitesse de l'onde de choc
uniform float turbulence_speed : hint_range(0.0, 1.0) = 0.5; // Vitesse du scintillement
uniform vec4 tint_color : source_color = vec4(1.0, 0.5, 0.2, 0.25); // Lueur orange/rouge

void fragment() {
	vec2 uv_local = UV * 2.0 - 1.0;
	float dist_rel = length(uv_local);

	// On ne dessine rien en dehors du cercle
	if (dist_rel > 1.0) {
		discard;
	}

	// Atténuation sur les bords
	float falloff = pow(1.0 - dist_rel, 2.0);

	// 1. L'onde de choc pulsante
	// Une onde qui part du centre et se propage vers l'extérieur
	float pulse_wave = sin(dist_rel * 15.0 - TIME * pulse_speed) * 0.5 + 0.5;
	vec2 pulse_distortion = normalize(uv_local) * pulse_wave * strength * 0.5;

	// 2. La turbulence scintillante
	// Un bruit qui bouge verticalement pour simuler l'air chaud qui monte
	vec2 noise_uv = UV + vec2(0.0, -TIME * turbulence_speed);
	float turbulence = (texture(noise_texture, noise_uv).r - 0.5) * 2.0;
	vec2 turbulence_distortion = vec2(turbulence, 0.0) * strength;

	// 3. On combine les deux distorsions
	vec2 final_distortion = (pulse_distortion + turbulence_distortion) * falloff;

	// On applique la distorsion à l'écran
	vec2 distorted_screen_uv = SCREEN_UV - final_distortion;
	vec4 screen_color = texture(SCREEN_TEXTURE, distorted_screen_uv);

	// 4. On ajoute la lueur chaude
	// Le mixage est plus fort au centre grâce au falloff
	vec3 final_color = mix(screen_color.rgb, tint_color.rgb, falloff * tint_color.a);

	// 5. On applique l'alpha pour les bords doux
	float final_alpha = screen_color.a * falloff;

	COLOR = vec4(final_color, final_alpha);
}