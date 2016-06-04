#version 400

layout(points) in;
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
in vec3 v_col[1];
in int v_nmask[1];
out vec3 g_col;
out vec3 g_wnorm;
out vec3 g_wpos;

void dopoint(vec3 bpos)
{
	gl_Position = Mproj * Mcam * vec4(bpos, 1.0);
	g_wpos = bpos;
	EmitVertex();
}

void main()
{
	g_col = v_col[0];
	vec3 bpos = gl_in[0].gl_Position.xyz;
	int nmask = v_nmask[0];
	switch(nmask) {
		case 0U:
			g_wnorm = vec3(-1.0, 0.0, 0.0);
			dopoint(bpos + vec3(0.0, 0.0, 0.0));
			dopoint(bpos + vec3(0.0, 0.0, 1.0));
			dopoint(bpos + vec3(0.0, 1.0, 0.0));
			dopoint(bpos + vec3(0.0, 1.0, 1.0));
			break;

		case 1U:
			g_wnorm = vec3( 0.0,-1.0, 0.0);
			dopoint(bpos + vec3(0.0, 0.0, 0.0));
			dopoint(bpos + vec3(1.0, 0.0, 0.0));
			dopoint(bpos + vec3(0.0, 0.0, 1.0));
			dopoint(bpos + vec3(1.0, 0.0, 1.0));
			break;

		case 2U:
			g_wnorm = vec3( 0.0, 0.0,-1.0);
			dopoint(bpos + vec3(0.0, 0.0, 0.0));
			dopoint(bpos + vec3(0.0, 1.0, 0.0));
			dopoint(bpos + vec3(1.0, 0.0, 0.0));
			dopoint(bpos + vec3(1.0, 1.0, 0.0));
			break;

		case 3U:
			g_wnorm = vec3( 1.0, 0.0, 0.0);
			dopoint(bpos + vec3(1.0, 0.0, 0.0));
			dopoint(bpos + vec3(1.0, 1.0, 0.0));
			dopoint(bpos + vec3(1.0, 0.0, 1.0));
			dopoint(bpos + vec3(1.0, 1.0, 1.0));
			break;

		case 4U:
			g_wnorm = vec3( 0.0, 1.0, 0.0);
			dopoint(bpos + vec3(0.0, 1.0, 0.0));
			dopoint(bpos + vec3(0.0, 1.0, 1.0));
			dopoint(bpos + vec3(1.0, 1.0, 0.0));
			dopoint(bpos + vec3(1.0, 1.0, 1.0));
			break;

		case 5U:
			g_wnorm = vec3( 0.0, 0.0, 1.0);
			dopoint(bpos + vec3(0.0, 0.0, 1.0));
			dopoint(bpos + vec3(1.0, 0.0, 1.0));
			dopoint(bpos + vec3(0.0, 1.0, 1.0));
			dopoint(bpos + vec3(1.0, 1.0, 1.0));
			break;
	}
}


