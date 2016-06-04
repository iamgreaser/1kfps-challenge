#version 400

layout(triangles) in;
//layout(invocations = 1) in;
layout(triangle_strip, max_vertices = 4) out;

uniform vec3 campos;

// tests for Mesa 12.1/13.0, whichever it's going to be called
// once this bug is fixed i'll switch the ver back to 430
//const float[] EXAMPLE1 = {1.0, 2.0, 3.0};
//const float[] EXAMPLE2 = {1.0, 2.0, 3.0, };
//const vec3[] EXAMPLE3 = {vec3(1.0, 2.0, 3.0), vec3(4.0, 5.0, 6.0)};
//const vec3[] EXAMPLE4 = {vec3(1.0, 2.0, 3.0), vec3(4.0, 5.0, 6.0), };
//const vec3[] EXAMPLE5 = {{1.0, 2.0, 3.0}, {4.0, 5.0, 6.0}};
//const vec3[] EXAMPLE6 = {{1.0, 2.0, 3.0}, {4.0, 5.0, 6.0}, };
//const vec3[] EXAMPLE7 = {{1.0, 2.0, 3.0, }, {4.0, 5.0, 6.0, }};
//const vec3[] EXAMPLE8 = {{1.0, 2.0, 3.0, }, {4.0, 5.0, 6.0, }, };
//const float[] NONC1 = float[](1.0, 2.0, 3.0);
//const vec3[] NONC2 = vec3[](vec3(1.0, 2.0, 3.0), vec3(4.0, 5.0, 6.0));
//const vec3[] INVALID1 = vec3[]({1.0, 2.0, 3.0}, {4.0, 5.0, 6.0});

uniform mat4 Mproj, Mcam;
in vec3 v_col[3];
in int v_nmask[3];
out vec3 g_col;
out vec3 g_wnorm;
out vec3 g_wpos;

void main()
{
	vec3 p0 = gl_in[0].gl_Position.xyz;
	vec3 p1 = gl_in[1].gl_Position.xyz;
	vec3 p2 = gl_in[2].gl_Position.xyz;
	g_wnorm = cross(p1-p0, p2-p0);

	for(int i = 0; i < 3; i++) {
		vec3 bpos = gl_in[i].gl_Position.xyz;
		gl_Position = Mproj * Mcam * gl_in[i].gl_Position;
		g_col = v_col[i];
		g_wpos = bpos;
		EmitVertex();
	}
	g_wpos = p1+p2-p0;
	gl_Position = Mproj * Mcam * vec4(p1+p2-p0, 1.0);
	EmitVertex();
}


