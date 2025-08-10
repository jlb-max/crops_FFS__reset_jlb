// res://shaders/heatHaze.gds (Version corrigée)
shader_type canvas_item;
// On passe en mode de mélange standard
render_mode blend_mix; 

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : source_color, filter_linear_mipmap;

uniform float strength : hint_range(0.0, 0.05) = 0.005;
uniform float speed : hint_range(0.0, 0.5) = 0.1;
uniform float turbulence : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv_local = UV * 2.0 - 1.0;
	float dist_rel = length(uv_local);

	if (dist_rel > 1.0) {
		discard;
	}

	// On calcule le "falloff" pour l'atténuation sur les bords (ne change pas)
	float falloff = 1.0 - dist_rel;

	// Le reste de tes calculs de bruit et de distorsion est parfait (ne change pas)
	vec2 uv_scroll_main = UV + vec2(0.0, -TIME * speed);
	vec2 uv_scroll_turb = UV + vec2(TIME * speed * 0.2, -TIME * speed * 0.8);
	float noise1 = texture(noise_texture, uv_scroll_main).r;
	float noise2 = texture(noise_texture, uv_scroll_turb).r;
	noise1 = (noise1 - 0.5) * 2.0;
	noise2 = (noise2 - 0.5) * 2.0;
	vec2 offset;
	offset.x = noise1;
	offset.y = noise2 * turbulence;
	vec2 screen_uv_distorted = SCREEN_UV - offset * strength * falloff;

	// --- LA CORRECTION EST ICI ---
	// On récupère la couleur déformée
	vec4 final_color = texture(SCREEN_TEXTURE, screen_uv_distorted);
	// On applique le falloff à la transparence pour créer des bords doux
	final_color.a *= falloff;
	// On affiche le résultat
	COLOR = final_color;
}