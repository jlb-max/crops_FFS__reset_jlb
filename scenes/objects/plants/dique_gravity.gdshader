// rippling_gravity.gdshader (inspiré de ShaderToy)
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- TES CONTRÔLES ---
// La force/hauteur des vagues (sera liée à Gravity Influence)
uniform float strength : hint_range(0.0, 0.05, 0.001) = 0.005; 
// Le nombre d'anneaux dans l'onde (sera lié à un paramètre visuel)
uniform float frequency : hint_range(1.0, 50.0, 1.0) = 20.0;
// La vitesse de propagation des ondes (sera lié à un paramètre visuel)
uniform float speed : hint_range(0.0, 10.0, 0.1) = 3.0;

void fragment() {
	// -- Notre base de coordonnées stable --
	vec2 uv_local = UV * 2.0 - 1.0;
	float dist_rel = length(uv_local);

	if (dist_rel > 1.0) {
		discard;
	}
	// Notre atténuation sur les bords pour la fusion
	float falloff = pow(1.0 - dist_rel, 2.0); 

	// -- La "formule magique" de ton shader d'exemple --
	// On crée l'ondulation concentrique avec un cosinus.
	float ripple = cos(dist_rel * frequency - TIME * speed) * strength;
	
	// On crée un vecteur de distorsion qui pousse/tire les pixels depuis le centre.
	vec2 distortion_vector = normalize(uv_local) * ripple * falloff;
	
	// On applique la distorsion finale à l'écran.
	vec2 distorted_uv = SCREEN_UV - distortion_vector;
	
	// --- NOTRE SYSTÈME DE RENDU FINAL ---
	vec4 final_color = texture(SCREEN_TEXTURE, distorted_uv);
	
	// On applique la transparence pour une fusion parfaite.
	final_color.a *= falloff;
	
	COLOR = final_color;
}