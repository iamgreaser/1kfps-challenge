#version 430

const float FOG_LIMIT = 128.0;
const int VXL_CSIZE = 8;
const int VXL_CX = 512/VXL_CSIZE;
const int VXL_CZ = 512/VXL_CSIZE;

uniform mat4 Mproj, Mcam;
uniform vec3 campos;

struct st_data { uint v, c; };
struct st_instance { int count, icount, first, ifirst; };
struct st_chunk { int len, offs, ymin, ymax; };

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding=0) buffer buf_data_in { st_data data_in[]; };
layout(std430, binding=1) buffer buf_chunk_in { st_chunk chunk_in[]; };
layout(std430, binding=2) buffer buf_data_out { st_data data_out[]; };
layout(std430, binding=3) buffer buf_indirect_out { st_instance indirect_out[]; };

const float shade_xn = 0.9;
const float shade_xp = 0.7;
const float shade_yn = 0.5;
const float shade_yp = 1.0;
const float shade_zn = 0.8;
const float shade_zp = 0.8;

const int MAP_HEIGHT = 64;

void main()
{
	int cx = int(gl_WorkGroupID.x);
	int cz = int(gl_WorkGroupID.y);

	int cidx = cx + VXL_CX*cz;
	int dlen  = chunk_in[cidx].len;
	int doffs = chunk_in[cidx].offs;
	int poffs = doffs*3;

	int di = poffs;

	vec2 rcv = vec2(cx, cz)*float(VXL_CSIZE);
	rcv -= campos.xz;
	if(rcv.x < 0.0) rcv.x = -rcv.x-float(VXL_CSIZE);
	if(rcv.y < 0.0) rcv.y = -rcv.y-float(VXL_CSIZE);
	float zc = length(rcv);

	float xratio = (Mproj * vec4(1.0, 0.0, 0.0, 0.0)).x;
	float yratio = (Mproj * vec4(0.0, 1.0, 0.0, 0.0)).y;
	vec3 cbox0 = vec3(cx*VXL_CSIZE, 253-chunk_in[cidx].ymax, cz*VXL_CSIZE);
	vec3 cbox1 = vec3((cx+1)*VXL_CSIZE, 259-chunk_in[cidx].ymin, (cz+1)*VXL_CSIZE);
	vec4 cplane0 = vec4(-xratio, 0.0, 1.0, 0.0);
	vec4 cplane1 = vec4( 0.0,-yratio, 1.0, 0.0);
	vec4 cplane2 = vec4( xratio, 0.0, 1.0, 0.0);
	vec4 cplane3 = vec4( 0.0,-yratio, 1.0, 0.0);
	vec4 campos4 = vec4(campos, 1.0);

	vec4 ccoffs = vec4(0.0);
	vec4 cbox000 = (Mcam * vec4(cbox0.x, cbox0.y, cbox0.z, 1.0)) + ccoffs;
	vec4 cbox001 = (Mcam * vec4(cbox0.x, cbox0.y, cbox1.z, 1.0)) + ccoffs;
	vec4 cbox010 = (Mcam * vec4(cbox0.x, cbox1.y, cbox0.z, 1.0)) + ccoffs;
	vec4 cbox011 = (Mcam * vec4(cbox0.x, cbox1.y, cbox1.z, 1.0)) + ccoffs;
	vec4 cbox100 = (Mcam * vec4(cbox1.x, cbox0.y, cbox0.z, 1.0)) + ccoffs;
	vec4 cbox101 = (Mcam * vec4(cbox1.x, cbox0.y, cbox1.z, 1.0)) + ccoffs;
	vec4 cbox110 = (Mcam * vec4(cbox1.x, cbox1.y, cbox0.z, 1.0)) + ccoffs;
	vec4 cbox111 = (Mcam * vec4(cbox1.x, cbox1.y, cbox1.z, 1.0)) + ccoffs;

	bool cfcull0 = (true
		&& dot(cplane0, cbox000) > 0.0
		&& dot(cplane0, cbox001) > 0.0
		&& dot(cplane0, cbox010) > 0.0
		&& dot(cplane0, cbox011) > 0.0
		&& dot(cplane0, cbox100) > 0.0
		&& dot(cplane0, cbox101) > 0.0
		&& dot(cplane0, cbox110) > 0.0
		&& dot(cplane0, cbox111) > 0.0
		);
	bool cfcull1 = (true
		&& dot(cplane1, cbox000) > 0.0
		&& dot(cplane1, cbox001) > 0.0
		&& dot(cplane1, cbox010) > 0.0
		&& dot(cplane1, cbox011) > 0.0
		&& dot(cplane1, cbox100) > 0.0
		&& dot(cplane1, cbox101) > 0.0
		&& dot(cplane1, cbox110) > 0.0
		&& dot(cplane1, cbox111) > 0.0
		);
	bool cfcull2 = (true
		&& dot(cplane2, cbox000) > 0.0
		&& dot(cplane2, cbox001) > 0.0
		&& dot(cplane2, cbox010) > 0.0
		&& dot(cplane2, cbox011) > 0.0
		&& dot(cplane2, cbox100) > 0.0
		&& dot(cplane2, cbox101) > 0.0
		&& dot(cplane2, cbox110) > 0.0
		&& dot(cplane2, cbox111) > 0.0
		);
	bool cfcull3 = (true
		&& dot(cplane3, cbox000) > 0.0
		&& dot(cplane3, cbox001) > 0.0
		&& dot(cplane3, cbox010) > 0.0
		&& dot(cplane3, cbox011) > 0.0
		&& dot(cplane3, cbox100) > 0.0
		&& dot(cplane3, cbox101) > 0.0
		&& dot(cplane3, cbox110) > 0.0
		&& dot(cplane3, cbox111) > 0.0
		);
	bool cfcull = cfcull0 || cfcull1 || cfcull2 || cfcull3;

	if(zc < FOG_LIMIT && !cfcull) {
	for(int i = 0; i < dlen; i++) {
		st_data p = data_in[i+doffs];
		vec3 rv = vec3(
			float((p.v>> 0)&0x3FFU),
			float((p.v>>10)&0x3FFU),
			float((p.v>>20)&0x3FFU));

		vec3 bpos = rv + vec3(0.5);
		float z0 = length(bpos - campos);
		vec4 f0 = Mproj * (Mcam * vec4(bpos, 1.0) + vec4(0.0, 0.0, -4.0, 0.0));
		vec2 if0 = abs(f0.xy)/max(0.01, f0.w);
		float f1 = max(if0.x*9.0/16.0, if0.y);

		if(z0 < FOG_LIMIT && f1 < 1.0){
			int nmask = int((p.c>>24U)&0xFFU);
			vec3 sidevec = bpos - campos;
			float nface = -1.0;
			float pface = 0.0;

			if((sidevec.x > pface && (nmask & 0x01) != 0)) {
				p.c = (p.c&0xFFFFFFU)|(0U<<24);
				data_out[di++] = p;
			}

			if((sidevec.y > pface && (nmask & 0x02) != 0)) {
				p.c = (p.c&0xFFFFFFU)|(1U<<24);
				data_out[di++] = p;
			}

			if((sidevec.z > pface && (nmask & 0x04) != 0)) {
				p.c = (p.c&0xFFFFFFU)|(2U<<24);
				data_out[di++] = p;
			}

			if((sidevec.x < nface && (nmask & 0x08) != 0)) {
				p.c = (p.c&0xFFFFFFU)|(3U<<24);
				data_out[di++] = p;
			}

			if((sidevec.y < nface && (nmask & 0x10) != 0)) {
				p.c = (p.c&0xFFFFFFU)|(4U<<24);
				data_out[di++] = p;
			}

			if((sidevec.z < nface && (nmask & 0x20) != 0)) {
				p.c = (p.c&0xFFFFFFU)|(5U<<24);
				data_out[di++] = p;
			}
		}
	}
	}

	indirect_out[cx + VXL_CX*cz].count = min(30000, max(0, di-poffs));
	indirect_out[cx + VXL_CX*cz].icount = 1;
	indirect_out[cx + VXL_CX*cz].first = poffs;
	indirect_out[cx + VXL_CX*cz].ifirst = 0;
}

