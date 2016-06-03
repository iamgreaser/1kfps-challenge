#version 430

const float FOG_LIMIT = 128.0;
const int VXL_CSIZE = 32;
const int VXL_CX = 512/32;
const int VXL_CZ = 512/32;

uniform mat4 Mproj, Mcam;
uniform vec3 campos;

struct st_data { uint v, c; };
struct st_instance { int count, icount, first, ifirst; };

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding=0) buffer buf_data_in {
	st_data data_in[]; };
layout(std430, binding=1) buffer buf_len_in { int len_in[]; };
layout(std430, binding=2) buffer buf_offs_in { int offs_in[]; };
layout(std430, binding=3) buffer buf_data_out {
	st_data data_out[]; };
layout(std430, binding=4) buffer buf_indirect_out {
	st_instance indirect_out[]; };

void main()
{
	int cx = int(gl_WorkGroupID.x);
	int cz = int(gl_WorkGroupID.y);

	int dlen  = len_in [cx + VXL_CX*cz];
	int doffs = offs_in[cx + VXL_CX*cz];

	int di = doffs;

	vec2 rcv = vec2(cx, cz)*float(VXL_CSIZE);
	rcv -= campos.xz;
	if(rcv.x < 0.0) rcv.x = -rcv.x-float(VXL_CSIZE);
	if(rcv.y < 0.0) rcv.y = -rcv.y-float(VXL_CSIZE);
	float zc = length(rcv);

	if(zc < FOG_LIMIT) {
	for(int i = 0; i < dlen; i++) {
		st_data p = data_in[i+doffs];
		vec3 rv = vec3(
			float((p.v>> 0)&0x3FFU),
			float((p.v>>10)&0x3FFU),
			float((p.v>>20)&0x3FFU));

		vec3 bpos = rv + vec3(0.5);
		float z0 = length(bpos - campos);

		if(z0 < FOG_LIMIT){
			vec4 f0 = Mproj * (Mcam * vec4(bpos, 1.0) + vec4(0.0, 0.0, -2.0, 0.0));
			vec2 if0 = abs(f0.xy)/max(0.01, f0.w);
			float f1 = max(if0.x*9.0/16.0, if0.y);

			if(f1 < 1.0) {
				int nmask = int((p.c>>24U)&0xFFU);
				vec3 sidevec = bpos - campos;
				int rnmask = 0;
				if(sidevec.x < 0.0) { rnmask |= 0x08; }
				if(sidevec.y < 0.0) { rnmask |= 0x10; }
				if(sidevec.z < 0.0) { rnmask |= 0x20; }
				rnmask |= ((nmask&0x07)&~(rnmask>>3));
				rnmask |= (((nmask>>3)&0x07)&(rnmask>>3));
				p.c = (p.c&0x00FFFFFFU)|(uint(rnmask)<<24U);
				data_out[di++] = p;
			}
		}
	}
	}

	indirect_out[cx + VXL_CX*cz].count = min(30000, max(0, di-doffs));
	indirect_out[cx + VXL_CX*cz].icount = 1;
	indirect_out[cx + VXL_CX*cz].first = doffs;
	indirect_out[cx + VXL_CX*cz].ifirst = 0;
}

