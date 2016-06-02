#version 330
// pending bugfix for 430 in mesa git

layout(points) in;
layout(triangle_strip, max_vertices = 12) out; // CHRISF WILL FUCKING KILL ME FOR THIS

uniform vec3 campos;

const float V0 = 0.0;
const float V1 = 1.0;
const float V2 = 1.0/sqrt(2.0);
const float V3 = 1.0/sqrt(3.0);
const float DX = 0.0;
const float DY = 1.0;
const float DZ = 0.0;

const vec3[] NORM_TAB = vec3[](
	vec3( DX, DY, DZ), vec3( V1, V0, V0), vec3(-V1, V0, V0), vec3( DX, DY, DZ),
	vec3( V0, V1, V0), vec3( V2, V2, V0), vec3(-V2, V2, V0), vec3( V0, V1, V0),
	vec3( V0,-V1, V0), vec3( V2,-V2, V0), vec3(-V2,-V2, V0), vec3( V0,-V1, V0),
	vec3( DX, DY, DZ), vec3( V1, V0, V0), vec3(-V1, V0, V0), vec3( DX, DY, DZ),

	vec3( V0, V0, V1), vec3( V2, V0, V2), vec3(-V2, V0, V2), vec3( V0, V0, V1),
	vec3( V0, V2, V2), vec3( V3, V3, V3), vec3(-V3, V3, V3), vec3( V0, V2, V2),
	vec3( V0,-V2, V2), vec3( V3,-V3, V3), vec3(-V3,-V3, V3), vec3( V0,-V2, V2),
	vec3( V0, V0, V1), vec3( V2, V0, V2), vec3(-V2, V0, V2), vec3( V0, V0, V1),

	vec3( V0, V0,-V1), vec3( V2, V0,-V2), vec3(-V2, V0,-V2), vec3( V0, V0,-V1),
	vec3( V0, V2,-V2), vec3( V3, V3,-V3), vec3(-V3, V3,-V3), vec3( V0, V2,-V2),
	vec3( V0,-V2,-V2), vec3( V3,-V3,-V3), vec3(-V3,-V3,-V3), vec3( V0,-V2,-V2),
	vec3( V0, V0,-V1), vec3( V2, V0,-V2), vec3(-V2, V0,-V2), vec3( V0, V0,-V1),

	vec3( DX, DY, DZ), vec3( V1, V0, V0), vec3(-V1, V0, V0), vec3( DX, DY, DZ),
	vec3( V0, V1, V0), vec3( V2, V2, V0), vec3(-V2, V2, V0), vec3( V0, V1, V0),
	vec3( V0,-V1, V0), vec3( V2,-V2, V0), vec3(-V2,-V2, V0), vec3( V0,-V1, V0),
	vec3( DX, DY, DZ), vec3( V1, V0, V0), vec3(-V1, V0, V0), vec3( DX, DY, DZ));

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
const float[] NONC1 = float[](1.0, 2.0, 3.0);
const vec3[] NONC2 = vec3[](vec3(1.0, 2.0, 3.0), vec3(4.0, 5.0, 6.0));
//const vec3[] INVALID1 = vec3[]({1.0, 2.0, 3.0}, {4.0, 5.0, 6.0});

uniform mat4 Mproj, Mcam;
in vec3 v_col[1];
in int v_nmask[1];
in int v_kill[1];
out vec3 g_col;
out vec3 g_wnorm;
out vec3 g_wpos;

void main()
{
	if(v_kill[0] > 0) {
		vec3 bpos = gl_in[0].gl_Position.xyz;
		g_col = v_col[0];
		int nmask = v_nmask[0];

		vec3 ppos;

		vec3 vx = (vec3(1.0, 0.0, 0.0));
		vec3 vy = (vec3(0.0, 1.0, 0.0));
		vec3 vz = (vec3(0.0, 0.0, 1.0));
		vec3 sidevec = bpos - campos;
		float sidex = -sidevec.x;
		float sidey = -sidevec.y;
		float sidez = -sidevec.z;

		if(sidex < 0.0 && (nmask & 0x01) != 0) {
	g_wnorm = -vx;
	ppos = ((bpos)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + vz)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + vy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + vy + vz)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidex >= 0.0 && (nmask & 0x08) != 0) {
	g_wnorm = vx;
	vec3 bposx = bpos + vx;
	ppos = ((bposx)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bposx + vz)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bposx + vy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bposx + vy + vz)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidey < 0.0 && (nmask & 0x02) != 0) {
	g_wnorm = -vy;
	ppos = ((bpos)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + vz)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + vx)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + vx + vz)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidey >= 0.0 && (nmask & 0x10) != 0) {
	g_wnorm = vy;
	vec3 bposy = bpos + vy;
	ppos = ((bposy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bposy + vz)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bposy + vx)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bposy + vx + vz)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidez < 0.0 && (nmask & 0x04) != 0) {
	g_wnorm = -vz;
	ppos = ((bpos)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + vy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + vx)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + vx + vy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidez >= 0.0 && (nmask & 0x20) != 0) {
	g_wnorm = vz;
	vec3 bposz = bpos + vz;
	ppos = ((bposz)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bposz + vy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bposz + vx)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bposz + vx + vy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

	}
}


