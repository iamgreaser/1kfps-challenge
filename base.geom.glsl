#version 150

layout(points) in;
//layout(invocations = 1) in;
layout(triangle_strip, max_vertices = 12) out;

const bool CULL_FACE = true; // control inner-face culling
//const bool INSTANCED = false; // enable GS instancing (gl_InvocationID, not gl_InstanceID)

uniform vec3 campos;

const float V0 = 0.0;
const float V1 = 1.0;
const float V2 = 1.0/sqrt(2.0);
const float V3 = 1.0/sqrt(3.0);
const float DX = 0.0;
const float DY = 1.0;
const float DZ = 0.0;

/*
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
*/

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
in int v_kill[1];
out vec3 g_col;
out vec3 g_wnorm;
out vec3 g_wpos;

void main()
{
	const float shade_xn = 0.9;
	const float shade_xp = 0.7;
	const float shade_yn = 0.5;
	const float shade_yp = 1.0;
	const float shade_zn = 0.8;
	const float shade_zp = 0.8;
	const vec3 shade_n = vec3(shade_xn, shade_yn, shade_zn);
	const vec3 shade_p = vec3(shade_xp, shade_yp, shade_zp);

	if(v_kill[0] > 0) {
		vec3 bpos = gl_in[0].gl_Position.xyz;
		vec3 bcol = v_col[0];
		int nmask = v_nmask[0];

		vec3 ppos;

		vec3 nvx = (vec3(1.0, 0.0, 0.0));
		vec3 nvy = (vec3(0.0, 1.0, 0.0));
		vec3 nvz = (vec3(0.0, 0.0, 1.0));
		float shade_x = shade_xn;
		float shade_y = shade_yn;
		float shade_z = shade_zn;

		//if((!INSTANCED)  || gl_InvocationID == 0) {
		if((!CULL_FACE) || (nmask & 0x01) != 0) {
	if((nmask & 0x08) != 0) { nvx = -nvx; shade_x = shade_xp; }
	g_col = bcol * shade_x;
	vec3 norm = -nvx;
	g_wnorm = norm;
	vec3 hnorm = norm/2.0;
	ppos = ((bpos + hnorm - hnorm.yzx - hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + hnorm + hnorm.yzx - hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + hnorm - hnorm.yzx + hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + hnorm + hnorm.yzx + hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}
		//}

		//if((!INSTANCED)  || gl_InvocationID == 1) {
		if((!CULL_FACE) || (nmask & 0x02) != 0) {
	if((nmask & 0x10) != 0) { nvy = -nvy; shade_y = shade_yp; }
	g_col = bcol * shade_y;
	vec3 norm = -nvy;
	g_wnorm = norm;
	vec3 hnorm = norm/2.0;
	ppos = ((bpos + hnorm - hnorm.yzx - hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + hnorm + hnorm.yzx - hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + hnorm - hnorm.yzx + hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + hnorm + hnorm.yzx + hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}
		//}

		//if((!INSTANCED)  || gl_InvocationID == 2) {
		if((!CULL_FACE) || (nmask & 0x04) != 0) {
	if((nmask & 0x20) != 0) { nvz = -nvz; shade_z = shade_zp; }
	g_col = bcol * shade_z;
	vec3 norm = -nvz;
	g_wnorm = norm;
	vec3 hnorm = norm/2.0;
	ppos = ((bpos + hnorm - hnorm.yzx - hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + hnorm + hnorm.yzx - hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + hnorm - hnorm.yzx + hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	ppos = ((bpos + hnorm + hnorm.yzx + hnorm.zxy)).xyz; g_wpos = ppos;
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}
		//}
	}
}


