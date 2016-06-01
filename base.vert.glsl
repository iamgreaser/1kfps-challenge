#version 430

uniform mat4 Mproj, Mcam;
in vec3 a_vtx;
in vec4 a_col;
out vec3 v_col;
out int v_kill;
//out vec3 v_anorm;
out int v_nmask;

void main()
{
	gl_Position = Mcam * vec4(a_vtx, 1.0);
	//gl_Position = vec4(a_vtx, 1.0);
	float z0 = length(gl_Position.xyz);
	float f0 = -normalize(gl_Position.xyz).z;
	vec4 ppoint4 = (Mproj * (gl_Position + vec4(0.0, 0.0, -1.8, 0.0)));
	vec3 ppoint3 = ppoint4.xyz/max(0.01, ppoint4.w);
	//v_kill = (z0 < 400.0 && f0 > 0.3 ? 1 : 0);
	//v_kill = (z0 < 127.5 && max(abs(ppoint3.x),abs(ppoint3.y)) < 1.0 ? 1 : 0);
	v_kill = (max(abs(ppoint3.x),abs(ppoint3.y)) < 1.0 ? 1 : 0);
	//v_kill = (z0 < 127.5 ? 1 : 0);
	v_col = a_col.bgr/255.0;
	//gl_PointSize = min(8.0,600.0/max(1.0,abs(z0)));
	int nmask = int(floor(a_col.a+0.5));
	v_nmask = nmask;

	//v_anorm = vec3(0.0);
	//vec3 tra_vtx = a_vtx + (Mcam * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	//vec3 tra_vtx = gl_Position.xyz;
	/*
	if((nmask & 0x01) == 0x01 && tra_vtx.x <= 0.0) { v_anorm.x -= 1.0; }
	if((nmask & 0x02) == 0x02 && tra_vtx.x >= 0.0) { v_anorm.x += 1.0; }
	if((nmask & 0x04) == 0x04 && tra_vtx.y <= 0.0) { v_anorm.y += 1.0; }
	if((nmask & 0x08) == 0x08 && tra_vtx.y >= 0.0) { v_anorm.y -= 1.0; }
	if((nmask & 0x10) == 0x10 && tra_vtx.z <= 0.0) { v_anorm.z -= 1.0; }
	if((nmask & 0x20) == 0x20 && tra_vtx.z >= 0.0) { v_anorm.z += 1.0; }
	if(length(v_anorm) < 0.1) {
		v_anorm = vec3(0.0, 1.0, 0.0);
	}
	//v_col.rgb = vec3(float(nmask)/63.0);
	//v_anorm = normalize(v_anorm);
	v_anorm = normalize((Mcam * (vec4(v_anorm, 0.0))).xyz);
	*/
}

