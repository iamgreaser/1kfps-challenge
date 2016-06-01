#version 430

layout(points) in;
layout(triangle_strip, max_vertices = 24) out; // CHRISF WILL FUCKING KILL ME FOR THIS

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
		/*
		g_snorm = normalize(cross(
			gl_in[1].gl_Position.xyz-gl_in[0].gl_Position.xyz,
			gl_in[2].gl_Position.xyz-gl_in[0].gl_Position.xyz));
		*/
		//g_snorm = normalize(vec3(1.0, 1.0, 1.0));
		//g_snorm = v_anorm[0];

		vec3 bpos = gl_in[0].gl_Position.xyz;
		g_col = v_col[0];
		int nmask = v_nmask[0];

		vec3 ppos;

		vec3 vx = (Mcam * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
		vec3 vy = (Mcam * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
		vec3 vz = (Mcam * vec4(0.0, 0.0, 1.0, 0.0)).xyz;

		if((nmask & 0x01) != 0) {
	g_snorm = -vx;
	ppos = bpos; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vz; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vy; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vy + vz; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if((nmask & 0x02) != 0) {
	g_snorm = vx;
	ppos = bpos + vx; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vx + vy; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vx + vz; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vx + vy + vz; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if((nmask & 0x08) != 0) {
	g_snorm = -vy;
	ppos = bpos; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vx; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vz; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vx + vz; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if((nmask & 0x04) != 0) {
	g_snorm = vy;
	ppos = bpos + vy; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vy + vz; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vy + vx; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vy + vx + vz; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if((nmask & 0x10) != 0) {
	g_snorm = -vz;
	ppos = bpos; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vy; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vx; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vy + vx; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

		if((nmask & 0x20) != 0) {
	g_snorm = vz;
	ppos = bpos + vz; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vz + vx; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vz + vy; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	ppos = bpos + vz + vy + vx; g_spos = ppos; gl_Position = Mproj * vec4(ppos, 1.0); EmitVertex();
	EndPrimitive();
		}

	}
}


