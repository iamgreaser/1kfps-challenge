#version 400
//extension GL_ARB_cull_distance: require

const float FOG_LIMIT = 128.0;

uniform mat4 Mproj, Mcam;
uniform vec3 campos;
in vec3 a_vtx;
in vec4 a_col;
out vec3 v_col;
//out int v_kill;
out int v_nmask;

void main()
{
	gl_Position = vec4(a_vtx + vec3(0.5), 1.0);
	v_col = a_col.bgr/255.0;
	v_nmask = int(floor(a_col.a+0.5));
}

