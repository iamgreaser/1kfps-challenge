#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <unistd.h>

#include <math.h>

#include <epoxy/gl.h>
#include <SDL.h>

// from https://github.com/datenwolf/linmath.h
#include "linmath.h"

#define INIT_WIDTH 800
#define INIT_HEIGHT 600

SDL_Window *window;
SDL_GLContext context;

uint8_t vxldata;
int key_mxp = 0;
int key_mxn = 0;
int key_myp = 0;
int key_myn = 0;
int key_mzp = 0;
int key_mzn = 0;
int key_ryp = 0;
int key_ryn = 0;
int key_rxp = 0;
int key_rxn = 0;

GLuint tri_vao;
GLuint tri_vbo;
struct cubept {
	GLuint v,c;
};
struct cubept tri_mesh_points[8] = {
	{0x00100000,0xFFFF0000},
	{0x00100001,0xFFFF00FF},
	{0x00100400,0xFFFFFF00},
	{0x00100401,0xFFFFFFFF},
	{0x00000000,0xFF000000},
	{0x00000001,0xFF0000FF},
	{0x00000400,0xFF00FF00},
	{0x00000401,0xFF00FFFF},
};

GLuint tri_mesh_indices[] = {
	4, 2, 6, 2, 4, 0, // -X
	1, 7, 3, 7, 1, 5, // +X
	2, 3, 7, 7, 6, 2, // -Y
	4, 5, 1, 1, 0, 4, // +Y
	5, 4, 7, 6, 7, 4, // -Z
	0, 1, 2, 3, 2, 1, // +Z

	/*
	0, 1,
	2, 3, 7,
	1, 5, 4,
	7, 6, 2,
	4, 0, 1,
	*/
};

#define FOG_LIMIT 128
#define VXL_LX 512
#define VXL_LZ 512
#define VXL_LY 256
#define VXL_LY_BMASK ((VXL_LY+31)>>5)
#define VXL_CSIZE 32
#define VXL_CX ((VXL_LX+VXL_CSIZE-1)/VXL_CSIZE)
#define VXL_CZ ((VXL_LZ+VXL_CSIZE-1)/VXL_CSIZE)
uint8_t *vxl_data[VXL_LZ][VXL_LX];
int vxl_data_len[VXL_LZ][VXL_LX];
int vxl_chunk_offs[VXL_CZ][VXL_CX];
int vxl_chunk_len[VXL_CZ][VXL_CX];
int vxl_chunk_ymin[VXL_CZ][VXL_CX];
int vxl_chunk_ymax[VXL_CZ][VXL_CX];
uint32_t vxl_data_bitmasks[VXL_LZ][VXL_LX][VXL_LY_BMASK];

int vxl_cube_count = 0;
struct cubept *vxl_mesh_points = NULL;

GLuint shader_prog;

void show_shader_log(GLuint shader, const char *desc)
{
	GLint loglen = 4096;
	glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &loglen);
	if(loglen < 1) { loglen = 1; }
	loglen++;
	char *buf = malloc(loglen+1);
	GLsizei real_loglen;
	glGetShaderInfoLog(shader, loglen, &real_loglen, buf);
	printf("=== %s (%d/%d) === {\n%s\n}\n", desc, real_loglen, loglen, buf);
	free(buf);
}

void show_program_log(GLuint program, const char *desc)
{
	GLint loglen = 4096;
	glGetProgramiv(program, GL_INFO_LOG_LENGTH, &loglen);
	if(loglen < 1) { loglen = 1; }
	loglen++;
	char *buf = malloc(loglen+1);
	GLsizei real_loglen;
	glGetProgramInfoLog(program, loglen, &real_loglen, buf);
	printf("=== %s (%d/%d) === {\n%s\n}\n", desc, real_loglen, loglen, buf);
	free(buf);
}

void *load_file_to_string(const char *fname)
{
	FILE *fp = fopen(fname, "rb");
	size_t buf_size = 0;
	char *buf = NULL;
	
	for(;;)
	{
		char subbuf[1024];
		ssize_t blen = fread(subbuf, 1, 1024, fp);
		if(blen < 0) {
			perror("load_file_to_string:fread");
			abort();
		}
		if(blen == 0) {
			break;
		}
		buf_size += blen;
		buf = realloc(buf, buf_size+1);
		if(buf == NULL) {
			perror("load_file_to_string:realloc");
			abort();
		}
		memcpy(buf+buf_size-blen, subbuf, blen);
	}

	fclose(fp);

	if(buf == NULL) {
		buf = malloc(1);
	}

	buf[buf_size] = '\x00';

	return buf;
}

void add_shader(GLuint program, const char *fname, GLenum category)
{
	const char *catheader = NULL;

	switch(category)
	{
		case GL_VERTEX_SHADER: catheader = "VERTEX SHADER"; break;
		case GL_TESS_CONTROL_SHADER: catheader = "TESSELATION CONTROL SHADER"; break;
		case GL_TESS_EVALUATION_SHADER: catheader = "TESSELATION EVALUATION SHADER"; break;
		case GL_GEOMETRY_SHADER: catheader = "GEOMETRY SHADER"; break;
		case GL_FRAGMENT_SHADER: catheader = "FRAGMENT SHADER"; break;
		default: abort(); for(;;) {} return;
	}

	GLchar *src_str = load_file_to_string(fname);
	GLchar const* src_str_cast = src_str;
	GLuint shader_obj = glCreateShader(category);
	glShaderSource(shader_obj, 1, &src_str_cast, NULL);
	glCompileShader(shader_obj);
	show_shader_log(shader_obj, catheader);
	glAttachShader(shader_prog, shader_obj);
}

int mask_is_set(int x, int y, int z)
{
	if(x < 0 || z < 0 || x >= VXL_LX || z >= VXL_LZ || y >= VXL_LY) {
		return 1;
	}

	if(y < 0) {
		return 0;
	}

	return (vxl_data_bitmasks[z][x][y>>5]>>(y&31))&1;
}

void load_vxl(const char *fname)
{
	FILE *fp = fopen(fname, "rb");

#define VXL_BUF_MAX 4096
	printf("Loading VXL file \"%s\"...\n", fname);

	vxl_cube_count = 0;

	int x,z;
	for(z = 0; z < VXL_LZ; z++) {
	for(x = 0; x < VXL_LX; x++) {
		uint8_t buf[VXL_BUF_MAX];
		int buf_len = 0;
		for(;;) {
			SDL_assert_release(buf_len+4 <= VXL_BUF_MAX);
			int hdr = buf_len;
			fread(buf+buf_len, 4, 1, fp);
			buf_len += 4;

			if(buf[hdr+0] == 0) {
				int vs = buf[hdr+1];
				int ve = buf[hdr+2];
				int runlen = ve-vs+1;
				vxl_cube_count += runlen;
				SDL_assert_release(runlen >= 0);
				SDL_assert_release(buf_len+4*runlen <= VXL_BUF_MAX);
				if(runlen > 0) {
					fread(buf+buf_len, 4, runlen, fp);
					buf_len += 4*runlen;
				}

				break;
			} else {
				int runlen = buf[hdr+0];
				runlen--;
				vxl_cube_count += runlen;
				SDL_assert_release(runlen >= 0);
				SDL_assert_release(buf_len+4*runlen <= VXL_BUF_MAX);
				if(runlen > 0) {
					fread(buf+buf_len, 4, runlen, fp);
					buf_len += 4*runlen;
				}
			}
		}
		vxl_data[z][x] = malloc(buf_len);
		memcpy(vxl_data[z][x], buf, buf_len);
		vxl_data_len[z][x] = buf_len;
	}
	}

	fclose(fp);
	printf("Building bit masks\n", vxl_cube_count);
	for(z = 0; z < VXL_LZ; z++) {
	for(x = 0; x < VXL_LX; x++) {
		int y;

		for(y = 0; y < VXL_LY_BMASK; y++) {
			SDL_assert_release(y >= 0 && y < VXL_LY_BMASK);
			vxl_data_bitmasks[z][x][y] = 0xFFFFFFFF;
		}

		uint8_t *p = vxl_data[z][x];

		int n,s,e,a;

		a = 0;
		for(;;) {
			n = p[0];
			s = p[1];
			e = p[2];

			for(y = a; y < s; y++) {
				SDL_assert_release((y>>5) >= 0 && (y>>5) < VXL_LY_BMASK);
				vxl_data_bitmasks[z][x][y>>5] &= ~(1<<(y&31));
			}
			if(n == 0) {
				break;
			}

			p += n*4;
			a = p[3];
		}
	}
	}

	printf("Generating mesh for %d cubes\n", vxl_cube_count);

	vxl_mesh_points = malloc(sizeof(tri_mesh_points)*vxl_cube_count);
	int mi = 0;

	int cz, cx;
	
	for(cz = 0; cz < VXL_CZ; cz++) {
	for(cx = 0; cx < VXL_CX; cx++) {
		vxl_chunk_offs[cz][cx] = mi;
		int cymin = 255;
		int cymax = 0;
	for(z = cz*VXL_CSIZE; z < (cz+1)*VXL_CSIZE; z++) {
	for(x = cx*VXL_CSIZE; x < (cx+1)*VXL_CSIZE; x++) {
		int y, j;

		uint8_t *p = vxl_data[z][x];

		int n,s,e,a;

		for(;;) {
			n = p[0];
			s = p[1];
			e = p[2];

			int flen = e-s+1;
			for(y = s; y <= e; y++) {
				SDL_assert_release(mi < vxl_cube_count);
				if(y < cymin) { cymin = y; }
				if(y > cymax) { cymax = y; }
				GLuint moffs = (z<<20)|((256-y)<<10)|(x<<0);
				vxl_mesh_points[mi].v = moffs;
				memcpy(&vxl_mesh_points[mi].c,
					p+4*(y-s+1), sizeof(GLuint));
				vxl_mesh_points[mi].c &= 0x00FFFFFF;
				if(!mask_is_set(x-1,y,z)) {
					vxl_mesh_points[mi].c |= (0x01<<24);
				}
				if(!mask_is_set(x+1,y,z)) {
					vxl_mesh_points[mi].c |= (0x08<<24);
				}
				if(!mask_is_set(x,y+1,z)) {
					vxl_mesh_points[mi].c |= (0x02<<24);
				}
				if(!mask_is_set(x,y-1,z)) {
					vxl_mesh_points[mi].c |= (0x10<<24);
				}
				if(!mask_is_set(x,y,z-1)) {
					vxl_mesh_points[mi].c |= (0x04<<24);
				}
				if(!mask_is_set(x,y,z+1)) {
					vxl_mesh_points[mi].c |= (0x20<<24);
				}
				mi++;
			}

			if(n == 0) {
				break;
			}

			p += n*4;
			a = p[3];
			int clen = n-1-flen;

			for(y = a-clen; y < a; y++) {
				SDL_assert_release(mi < vxl_cube_count);
				if(y < cymin) { cymin = y; }
				if(y > cymax) { cymax = y; }
				GLuint moffs = (z<<20)|((256-y)<<10)|(x<<0);
				vxl_mesh_points[mi].v = moffs;
				memcpy(&vxl_mesh_points[mi].c,
					p+4*(y-a), sizeof(GLuint));
				vxl_mesh_points[mi].c &= 0x00FFFFFF;
				if(!mask_is_set(x-1,y,z)) {
					vxl_mesh_points[mi].c |= (0x01<<24);
				}
				if(!mask_is_set(x+1,y,z)) {
					vxl_mesh_points[mi].c |= (0x08<<24);
				}
				if(!mask_is_set(x,y+1,z)) {
					vxl_mesh_points[mi].c |= (0x02<<24);
				}
				if(!mask_is_set(x,y-1,z)) {
					vxl_mesh_points[mi].c |= (0x10<<24);
				}
				if(!mask_is_set(x,y,z-1)) {
					vxl_mesh_points[mi].c |= (0x04<<24);
				}
				if(!mask_is_set(x,y,z+1)) {
					vxl_mesh_points[mi].c |= (0x20<<24);
				}
				mi++;
			}
		}
	}
	}
		vxl_chunk_len[cz][cx] = mi - vxl_chunk_offs[cz][cx];
		vxl_chunk_ymin[cz][cx] = 256-cymin;
		vxl_chunk_ymax[cz][cx] = 256-cymax;
	}
	}

	printf("VXL done! %d cubes\n", mi);
}

int main(int argc, char *argv[])
{
	int i, j;

	SDL_assert_release(argc > 1);

	(void)argc;
	(void)argv;
	SDL_Init(SDL_INIT_TIMER | SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE);

	window = SDL_CreateWindow("dankfps",
		SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
		INIT_WIDTH, INIT_HEIGHT,
		SDL_WINDOW_OPENGL);
	SDL_assert_release(window != NULL);

	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
	//SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
	//SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

	context = SDL_GL_CreateContext(window);
	SDL_assert_release(context);

	SDL_GL_SetSwapInterval(0); // disable vsync
	//SDL_GL_SetSwapInterval(-1); // late swap tearing if you want it

	load_vxl(argv[1]);

	shader_prog = glCreateProgram();
	add_shader(shader_prog, "base.vert.glsl", GL_VERTEX_SHADER);
	add_shader(shader_prog, "base.geom.glsl", GL_GEOMETRY_SHADER);
	add_shader(shader_prog, "base.frag.glsl", GL_FRAGMENT_SHADER);
	glBindFragDataLocation(shader_prog, 0, "f_col");
	glLinkProgram(shader_prog);
	show_program_log(shader_prog, "PROGRAM LINK");
	glUseProgram(shader_prog);

	mat4x4 Mproj, Mcam, MA, MB;
	mat4x4 Mcam_pos;
	mat4x4 Mcam_roty, Mcam_iroty;
	mat4x4 Mcam_rotx, Mcam_irotx;
	mat4x4_identity(Mproj);
	mat4x4_perspective(Mproj, 90.0f*M_PI/180.0f, INIT_WIDTH/(float)INIT_HEIGHT, 0.02f, FOG_LIMIT+3);
	glUniformMatrix4fv(glGetUniformLocation(shader_prog, "Mproj"), 1, GL_FALSE, Mproj[0]);

	mat4x4_identity(Mcam_roty);
	mat4x4_identity(Mcam_rotx);
	mat4x4_identity(Mcam_iroty);
	mat4x4_identity(Mcam_irotx);
	mat4x4_identity(Mcam_pos);
	mat4x4_translate_in_place(Mcam_pos, -256.5f, -240.0f, -256.5f);

	glGenVertexArrays(1, &tri_vao);
	glBindVertexArray(tri_vao);
	glGenBuffers(1, &tri_vbo);
	glBindBuffer(GL_ARRAY_BUFFER, tri_vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(tri_mesh_points)*vxl_cube_count,
		vxl_mesh_points, GL_STATIC_DRAW);
	GLuint a_vtx = glGetAttribLocation(shader_prog, "a_vtx");
	GLuint a_col = glGetAttribLocation(shader_prog, "a_col");
	glBindBuffer(GL_ARRAY_BUFFER, tri_vbo);
	glVertexAttribPointer(a_vtx, 4, GL_UNSIGNED_INT_2_10_10_10_REV, GL_FALSE, sizeof(struct cubept),
		&(((struct cubept *)0)->v));
	glVertexAttribPointer(a_col, 4, GL_UNSIGNED_BYTE, GL_FALSE, sizeof(struct cubept),
		&(((struct cubept *)0)->c));
	glEnableVertexAttribArray(a_vtx);
	glEnableVertexAttribArray(a_col);
	glBindVertexArray(0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);

	glClearColor(
		192.0f/255.0f,
		232.0f/255.0f,
		255.0f/255.0f,
		1.0f);
	glEnable(GL_DEPTH_TEST);
	//glEnable(GL_CULL_FACE);
	//glEnable(GL_PROGRAM_POINT_SIZE);

	int xradtab[VXL_CX*2+1];
	memset(xradtab, 0, sizeof(xradtab));
	for(i = 0; i <= (FOG_LIMIT+VXL_CSIZE-1)/VXL_CSIZE; i++) {
		int czdiff = (i-1)*VXL_CSIZE;
		if(czdiff < 0) { czdiff = 0; }
		int xrad = floor((sqrt(FOG_LIMIT*FOG_LIMIT-czdiff*czdiff)+VXL_CSIZE-1)/VXL_CSIZE);
		xradtab[VXL_CX+i] = xrad;
		xradtab[VXL_CX-i] = xrad;
	}

	int lasttime = SDL_GetTicks();
	int nextframe_time = lasttime + 1000;
	double sec_delta = 0.01;
	int frame_counter = 0;
	int running = 1;
	while(running) {
		double mvspeed = 40.0*sec_delta;
		double rtspeed = M_PI*2.0*0.5*sec_delta;
		double mvx = 0.0;
		double mvy = 0.0;
		double mvz = 0.0;
		double rty = 0.0;
		double rtx = 0.0;
		if(key_mxn) { mvx -= 1.0; }
		if(key_mxp) { mvx += 1.0; }
		if(key_myn) { mvy -= 1.0; }
		if(key_myp) { mvy += 1.0; }
		if(key_mzn) { mvz -= 1.0; }
		if(key_mzp) { mvz += 1.0; }
		if(key_ryn) { rty -= 1.0; }
		if(key_ryp) { rty += 1.0; }
		if(key_rxn) { rtx -= 1.0; }
		if(key_rxp) { rtx += 1.0; }

		mat4x4_rotate_Y(MA, Mcam_iroty, rtspeed*rty);
		mat4x4_dup(Mcam_iroty, MA);
		mat4x4_rotate_X(MA, Mcam_irotx, rtspeed*rtx);
		mat4x4_dup(Mcam_irotx, MA);
		mat4x4_rotate_Y(MA, Mcam_roty, -rtspeed*rty);
		mat4x4_dup(Mcam_roty, MA);
		mat4x4_rotate_X(MA, Mcam_rotx, -rtspeed*rtx);
		mat4x4_dup(Mcam_rotx, MA);

		vec4 svecA = {-mvspeed*mvx, -mvspeed*mvy, -mvspeed*mvz, 0.0f};
		vec4 dvecA = {0.0f, 0.0f, -1.0f, 0.0f};
		vec4 pvecA = {0.0f, 0.0f, 0.0f, -1.0f};
		vec4 svecB;
		vec4 dvecB;
		vec4 pvecB;
		mat4x4_mul(MA, Mcam_iroty, Mcam_irotx);
		mat4x4_mul_vec4(svecB, MA, svecA);
		mat4x4_mul_vec4(dvecB, MA, dvecA);
		float ddvec = sqrtf(0.0f
			+ dvecB[0]*dvecB[0]
			//+ dvecB[1]*dvecB[1]
			+ dvecB[2]*dvecB[2]);

		mat4x4_translate_in_place(Mcam_pos, svecB[0], svecB[1], svecB[2]);
		mat4x4_mul(MA, Mcam_rotx, Mcam_roty);
		mat4x4_mul(Mcam, MA, Mcam_pos);
		mat4x4_mul_vec4(pvecB, Mcam_pos, pvecA);

		int ccx = (int)floor(pvecB[0]/VXL_CSIZE);
		int ccz = (int)floor(pvecB[2]/VXL_CSIZE);
		//printf("%d %d\n", ccx, ccz);
		int cz1 = ccz - (FOG_LIMIT+VXL_CSIZE-1)/VXL_CSIZE;
		int cz2 = ccz + (FOG_LIMIT+VXL_CSIZE-1)/VXL_CSIZE + 1;
		if(cz1 < 0) { cz1 = 0; }
		if(cz2 >= VXL_CZ) { cz2 = VXL_CZ; }

		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glBindVertexArray(tri_vao);
		glUniformMatrix4fv(glGetUniformLocation(shader_prog, "Mcam"), 1, GL_FALSE, Mcam[0]);
		glUniform3fv(glGetUniformLocation(shader_prog, "campos"), 1, pvecB);
		int cx, cz;
		for(cz = cz1; cz < cz2; cz++) {
			int czdiff = (cz-ccz);
			int xrad = xradtab[VXL_CX+czdiff];
			int cx1 = ccx - xrad;
			int cx2 = ccx + xrad + 1;
			if(cx1 < 0) { cx1 = 0; }
			if(cx2 >= VXL_CX) { cx2 = VXL_CX; }
			if(cx1 >= cx2) { continue; }

			for(cx = cx1; cx < cx2; cx++) {
				float fx1 = (cx+0)*VXL_CSIZE;
				float fz1 = (cz+0)*VXL_CSIZE;
				float fx2 = (cx+1)*VXL_CSIZE;
				float fz2 = (cz+1)*VXL_CSIZE;
				float fy1 = vxl_chunk_ymin[cz][cx];
				float fy2 = vxl_chunk_ymax[cz][cx];
				if(1) {
					float frust_x = Mproj[0][0];
					float frust_y = Mproj[1][1];

					vec4 vp[4] = {
						{-frust_x, 0.0f,-1.0f,0.0f},
						{ 0.0f,-frust_y,-1.0f,0.0f},
						{ frust_x, 0.0f,-1.0f,0.0f},
						{ 0.0f, frust_y,-1.0f,0.0f},
					};

					vec4 vc[8];
					for(i = 0; i < 8; i++) {
						vec4 vt1;
						vt1[0] = ((i&1)==0 ? fx1 : fx2);
						vt1[1] = ((i&2)==0 ? fy1 : fy2);
						vt1[2] = ((i&4)==0 ? fz1 : fz2);
						vt1[3] = 1.0f;
						mat4x4_mul_vec4(vc[i], Mcam, vt1);
					}

					// TODO: fast delta-based version

					int all_outside = 0;
					for(i = 0; i < 4 && !all_outside; i++) {
						int any_inside = 0;

						for(j = 0; j < 8 && !any_inside; j++) {
							float d = vec4_mul_inner(vp[i], vc[j]);
							any_inside = (d > 0.0f);
						}

						if(!any_inside) {
							all_outside = 1;
						}
					}

					if(all_outside) {
						continue;
					}
				}

				int cpos = vxl_chunk_offs[cz][cx];
				int clen = vxl_chunk_len[cz][cx];
				if(clen > 0) {
					glDrawArrays(GL_POINTS, cpos, clen);
				}
			}
		}
		glBindVertexArray(0);

		SDL_GL_SwapWindow(window);
		usleep(100);
		int curframe_time = SDL_GetTicks();
		sec_delta = ((double)(curframe_time-lasttime))/1000.0;
		lasttime = curframe_time;
		frame_counter++;
		if(curframe_time >= nextframe_time) {
			char fpsbuf[64];
			sprintf(fpsbuf, "%4d FPS", frame_counter);
			printf("%s\n", fpsbuf);
			SDL_SetWindowTitle(window, fpsbuf);
			frame_counter = 0;
			nextframe_time += 1000;
		}

		SDL_Event ev;
		while(SDL_PollEvent(&ev)) {
			switch(ev.type) {
				case SDL_KEYUP:
				case SDL_KEYDOWN:
				switch(ev.key.keysym.sym) {
					case SDLK_w: key_mzn = (ev.type == SDL_KEYDOWN); break;
					case SDLK_s: key_mzp = (ev.type == SDL_KEYDOWN); break;
					case SDLK_a: key_mxn = (ev.type == SDL_KEYDOWN); break;
					case SDLK_d: key_mxp = (ev.type == SDL_KEYDOWN); break;
					case SDLK_LCTRL: key_myn = (ev.type == SDL_KEYDOWN); break;
					case SDLK_SPACE: key_myp = (ev.type == SDL_KEYDOWN); break;
					case SDLK_DOWN: key_rxn = (ev.type == SDL_KEYDOWN); break;
					case SDLK_UP: key_rxp = (ev.type == SDL_KEYDOWN); break;
					case SDLK_LEFT: key_ryn = (ev.type == SDL_KEYDOWN); break;
					case SDLK_RIGHT: key_ryp = (ev.type == SDL_KEYDOWN); break;
				} break;

				case SDL_QUIT:
					running = 0;
					break;
			}
		}
	}

	return 0;
}

