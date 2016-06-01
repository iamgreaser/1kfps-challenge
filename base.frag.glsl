#version 430

in vec3 g_col;
in vec3 g_snorm;
in vec3 g_spos;
out vec4 f_col;

void main()
{
	vec3 posdir = normalize(g_spos);
	vec3 ldir = normalize(g_spos);
	float diff = max(0.0, -dot(g_snorm, ldir));

	vec3 sdir = posdir-2.0*dot(ldir,posdir)*ldir;
	float spec = max(0.0, dot(g_snorm, sdir));
	float dist = length(g_spos);

	const float amb = 0.1;
	float ambdiff = amb + (1.0-amb)*diff;
	f_col = vec4(mix(
		g_col*ambdiff + vec3(1.0)*pow(spec, 128.0),
		vec3(192.0/255.0, 232.0/255.0, 255.0/255.0),
		min(1.0, pow(dist/127.5, 2.0))), 1.0);
	f_col = vec4(g_col*ambdiff, 1.0);
	
	//f_col = vec4(g_col, 1.0);
	//f_col = vec4(g_snorm*0.5+0.5, 1.0);
}

