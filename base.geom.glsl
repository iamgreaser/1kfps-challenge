#version 330
// pending bugfix for 430 in mesa git

layout(points) in;
layout(triangle_strip, max_vertices = 12) out; // CHRISF WILL FUCKING KILL ME FOR THIS

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
out vec3 g_snorm;
out vec3 g_spos;

void main()
{
	if(v_kill[0] > 0) {
		//g_snorm = normalize(vec3(1.0, 1.0, 1.0));
		//g_snorm = v_anorm[0];

		vec4 bpos = gl_in[0].gl_Position;
		g_col = v_col[0];
		int nmask = v_nmask[0];

		vec3 ppos;

		vec4 vx = (vec4(1.0, 0.0, 0.0, 0.0));
		vec4 vy = (vec4(0.0, 1.0, 0.0, 0.0));
		vec4 vz = (vec4(0.0, 0.0, 1.0, 0.0));
		vec3 rvx = (Mcam * vx).xyz;
		vec3 rvy = (Mcam * vy).xyz;
		vec3 rvz = (Mcam * vz).xyz;
		float sidex = -dot(Mcam * vx, Mcam * bpos);
		float sidey = -dot(Mcam * vy, Mcam * bpos);
		float sidez = -dot(Mcam * vz, Mcam * bpos);
		/*
		g_snorm = NORM_TAB[nmask&63];
		//g_snorm = vec3(0.0, 0.0, 1.0);
		if(dot(bpos, g_snorm) < 0.0) {
			float dotsz = 0.5*sqrt(3.0);
			ppos = bpos + dotsz*vec3(-1.0,-1.0, 0.0); g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
			ppos = bpos + dotsz*vec3( 1.0,-1.0, 0.0); g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
			ppos = bpos + dotsz*vec3(-1.0, 1.0, 0.0); g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
			ppos = bpos + dotsz*vec3( 1.0, 1.0, 0.0); g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
			EndPrimitive();
		}
		*/

		if(sidex < 0.0 && (nmask & 0x01) != 0) {
	g_snorm = -rvx;
	ppos = (Mcam * (bpos)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bpos + vz)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bpos + vy)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bpos + vy + vz)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidex >= 0.0 && (nmask & 0x08) != 0) {
	g_snorm = rvx;
	vec4 bposx = bpos + vx;
	ppos = (Mcam * (bposx)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bposx + vz)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bposx + vy)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bposx + vy + vz)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidey < 0.0 && (nmask & 0x02) != 0) {
	g_snorm = -rvy;
	ppos = (Mcam * (bpos)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bpos + vz)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bpos + vx)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bpos + vx + vz)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidey >= 0.0 && (nmask & 0x10) != 0) {
	g_snorm = rvy;
	vec4 bposy = bpos + vy;
	ppos = (Mcam * (bposy)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bposy + vz)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bposy + vx)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bposy + vx + vz)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidez < 0.0 && (nmask & 0x04) != 0) {
	g_snorm = -rvz;
	ppos = (Mcam * (bpos)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bpos + vy)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bpos + vx)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bpos + vx + vy)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if(sidez >= 0.0 && (nmask & 0x20) != 0) {
	g_snorm = rvz;
	vec4 bposz = bpos + vz;
	ppos = (Mcam * (bposz)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bposz + vy)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bposz + vx)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = (Mcam * (bposz + vx + vy)).xyz; g_spos = ppos;
	gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

	}
}


