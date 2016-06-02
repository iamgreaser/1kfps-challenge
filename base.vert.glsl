#version 330

const float FOG_LIMIT = 128.0;

uniform mat4 Mproj, Mcam;
uniform vec3 campos;
in vec3 a_vtx;
in vec4 a_col;
out vec3 v_col;
out int v_kill;
out int v_nmask;

void main()
{
	gl_Position = vec4(a_vtx, 1.0);
	//gl_Position = vec4(a_vtx, 1.0);
	float z0 = length(a_vtx + vec3(0.5) - campos);
	//float f0 = -normalize((Mcam * gl_Position).xyz).z;
	vec4 ppoint4 = (Mproj * ((Mcam * vec4(a_vtx + vec3(0.5), 1.0)) + vec4(0.0, 0.0, -2.0, 0.0)));
	vec3 ppoint3 = ppoint4.xyz/max(0.01, ppoint4.w);

	//v_kill = (z0 < 400.0 && f0 > 0.3 ? 1 : 0);
	//v_kill = (max(abs(ppoint3.x),abs(ppoint3.y)) < 1.0 ? 1 : 0);
	v_kill = (z0 < FOG_LIMIT && max(abs(ppoint3.x),abs(ppoint3.y)) < 1.0 ? 1 : 0);
	//v_kill = (z0 < FOG_LIMIT && f0 > 0.5 ? 1 : 0);
	//v_kill = (z0 < FOG_LIMIT ? 1 : 0);
	if(v_kill > 0) {
		v_col = a_col.bgr/255.0;
		int nmask = int(floor(a_col.a+0.5));
		v_nmask = nmask;
	}
}

