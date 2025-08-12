// true_gravity_from_heat.gdshader
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// On garde les mêmes uniforms que heatHaze pour une comparaison directe
uniform float strength : hint_range(0.0, 0.05) = 0.015;
uniform float speed : hint_range(0.0, 5.0) = 0.5;
// On ajoute une densité pour les vagues
uniform float wave_density : hint_range(1.0, 50.0) = 20.0;


void fragment() {
	vec2 uv_local = UV * 2.0 - 1.0;
	float dist_rel = length(uv_local);

	if (dist_rel > 1.0) {
		discard;
	}

	// On utilise le même falloff linéaire que heatHaze
	float falloff = 1.0 - dist_rel;

	// --- LA SEULE MODIFICATION EST ICI ---
	// Au lieu de lire dans une texture de bruit...
	
	// On génère deux ondes sinus différentes, comme si c'était nos deux "bruits".
	float wave1 = sin(dist_rel * wave_density + TIME * speed);
	float wave2 = cos(dist_rel * wave_density * 0.6 - TIME * speed * 1.5);

	// On utilise ces deux ondes pour créer un vecteur de déformation bidirectionnel,
	// exactement comme heatHaze le fait avec noise1 et noise2.
	vec2 offset;
	offset.x = wave1;
	offset.y = wave2;
	// --- Fin de la modification ---

	// Le reste du code est IDENTIQUE à votre shader heatHaze qui fonctionne.
	vec2 screen_uv_distorted = SCREEN_UV - offset * strength * falloff;

	vec4 final_color = texture(SCREEN_TEXTURE, screen_uv_distorted);
	final_color.a *= falloff;
	
	COLOR = final_color;
}