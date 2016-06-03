#version 400

layout(points) in;
layout(invocations = 1) in;
layout(triangle_strip, max_vertices = 12) out;

const bool CULL_FACE = true; // control inner-face culling
const bool INSTANCED = false; // enable GS instancing (gl_InvocationID, not gl_InstanceID)

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

void ptemit(vec3 ppos)
{
	gl_Position = Mproj * Mcam * vec4(ppos, 1.0);
	g_wpos = ppos;
	EmitVertex();
}

void quademit(vec3 bpos, vec3 norm, vec3 bcol)
{
	g_col = bcol;
	g_wnorm = norm;
	vec3 hnorm = norm/2.0;
	ptemit(bpos + hnorm - hnorm.yzx - hnorm.zxy);
	ptemit(bpos + hnorm + hnorm.yzx - hnorm.zxy);
	ptemit(bpos + hnorm - hnorm.yzx + hnorm.zxy);
	ptemit(bpos + hnorm + hnorm.yzx + hnorm.zxy);
	EndPrimitive();
}

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

	{
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

		if((!INSTANCED) || gl_InvocationID == 0) {
		if((!CULL_FACE) || (nmask & 0x01) != 0) {
			if((nmask & 0x08) != 0) { nvx = -nvx; shade_x = shade_xp; }
			quademit(bpos, -nvx, bcol * shade_x);
		}
		}

		if((!INSTANCED)  || gl_InvocationID == 1) {
		if((!CULL_FACE) || (nmask & 0x02) != 0) {
			if((nmask & 0x10) != 0) { nvy = -nvy; shade_y = shade_yp; }
			quademit(bpos, -nvy, bcol * shade_y);
		}
		}

		if((!INSTANCED)  || gl_InvocationID == 2) {
		if((!CULL_FACE) || (nmask & 0x04) != 0) {
			if((nmask & 0x20) != 0) { nvz = -nvz; shade_z = shade_zp; }
			quademit(bpos, -nvz, bcol * shade_z);
		}
		}
	}
}


