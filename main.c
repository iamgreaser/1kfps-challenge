#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <math.h>

#include <epoxy/gl.h>
#include <SDL.h>

// from https://github.com/datenwolf/linmath.h
#include "linmath.h"

#define INIT_WIDTH 1280
#define INIT_HEIGHT 720

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
GLuint tri_vbo_indices;
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

#define VXL_LX 512
#define VXL_LZ 512
#define VXL_LY 256
//define VXL_LY_BMASK ((VXL_LY+31)>>5)
#define VXL_LY_BMASK 8
uint8_t *vxl_data[VXL_LZ][VXL_LX];
int vxl_data_len[VXL_LZ][VXL_LX];
uint32_t vxl_data_bitmasks[VXL_LZ][VXL_LX][VXL_LY_BMASK];

int vxl_cube_count = 0;
int vxl_index_count = 0;
struct cubept *vxl_mesh_points = NULL;
GLuint *vxl_mesh_indices = NULL;

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
	vxl_mesh_indices = malloc(sizeof(tri_mesh_indices)*vxl_cube_count);
	int mi = 0;
	int ii = 0;

	for(z = 0; z < VXL_LZ; z++) {
	for(x = 0; x < VXL_LX; x++) {
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
				GLuint moffs = (z<<20)|((256-y)<<10)|(x<<0);
				for(j = 0; j < 8; j++) {
					memcpy(&vxl_mesh_points[mi*8+j].v,
						&tri_mesh_points[j], sizeof(GLuint));
					memcpy(&vxl_mesh_points[mi*8+j].c,
						p+4*(y-s+1), sizeof(GLuint));
					vxl_mesh_points[mi*8+j].v += moffs;
				}

				if(!mask_is_set(x-1,y,z)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[0*6+j];
				}
				}
				if(!mask_is_set(x+1,y,z)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[1*6+j];
				}
				}

				if(!mask_is_set(x,y-1,z)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[2*6+j];
				}
				}
				if(!mask_is_set(x,y+1,z)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[3*6+j];
				}
				}

				if(!mask_is_set(x,y,z-1)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[4*6+j];
				}
				}
				if(!mask_is_set(x,y,z+1)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[5*6+j];
				}
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
				GLuint moffs = (z<<20)|((256-y)<<10)|(x<<0);
				for(j = 0; j < 8; j++) {
					memcpy(&vxl_mesh_points[mi*8+j].v,
						&tri_mesh_points[j], sizeof(GLuint));
					memcpy(&vxl_mesh_points[mi*8+j].c,
						p+4*(y-a), sizeof(GLuint));
					vxl_mesh_points[mi*8+j].v += moffs;
				}

				if(!mask_is_set(x-1,y,z)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[0*6+j];
				}
				}
				if(!mask_is_set(x+1,y,z)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[1*6+j];
				}
				}

				if(!mask_is_set(x,y-1,z)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[2*6+j];
				}
				}
				if(!mask_is_set(x,y+1,z)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[3*6+j];
				}
				}

				if(!mask_is_set(x,y,z-1)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[4*6+j];
				}
				}
				if(!mask_is_set(x,y,z+1)) {
				for(j = 0; j < 6; j++) {
					vxl_mesh_indices[ii++] = mi*8+tri_mesh_indices[5*6+j];
				}
				}
				mi++;
			}
		}
	}
	}
	vxl_index_count = ii;

	printf("VXL done! %d cubes, %d/%d indices\n", mi, ii, vxl_cube_count*6*6);
}

int main(int argc, char *argv[])
{
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
	mat4x4_perspective(Mproj, M_PI/2.0f, INIT_WIDTH/(float)INIT_HEIGHT, 0.02f, 400.0f);
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
	glGenBuffers(1, &tri_vbo_indices);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, tri_vbo_indices);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(tri_mesh_indices)*vxl_cube_count,
		vxl_mesh_indices, GL_STATIC_DRAW);
	GLuint a_vtx = glGetAttribLocation(shader_prog, "a_vtx");
	GLuint a_col = glGetAttribLocation(shader_prog, "a_col");
	glBindBuffer(GL_ARRAY_BUFFER, tri_vbo);
	glVertexAttribPointer(a_vtx, 4, GL_UNSIGNED_INT_2_10_10_10_REV, GL_FALSE, sizeof(struct cubept),
		&(((struct cubept *)0)->v));
	glVertexAttribPointer(a_col, 3, GL_UNSIGNED_BYTE, GL_FALSE, sizeof(struct cubept),
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
	glEnable(GL_CULL_FACE);

	int nextframe_time = SDL_GetTicks() + 1000;
	int frame_counter = 0;
	int running = 1;
	while(running) {
		double sec_delta = 0.01;
		double mvspeed = 10.0*sec_delta;
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

		vec4 svecA = {-mvspeed*mvx, -mvspeed*mvy, -mvspeed*mvz, 1.0f};
		vec4 svecB;
		mat4x4_mul(MA, Mcam_iroty, Mcam_irotx);
		mat4x4_mul_vec4(svecB, MA, svecA);

		mat4x4_translate_in_place(Mcam_pos, svecB[0], svecB[1], svecB[2]);
		mat4x4_mul(MA, Mcam_rotx, Mcam_roty);
		mat4x4_mul(Mcam, MA, Mcam_pos);

		glUniformMatrix4fv(glGetUniformLocation(shader_prog, "Mcam"), 1, GL_FALSE, Mcam[0]);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glBindVertexArray(tri_vao);
		//glDrawElements(GL_TRIANGLE_STRIP, 
		glDrawElements(GL_TRIANGLES,
			//vxl_cube_count*(sizeof(tri_mesh_indices)/sizeof(GLuint)),
			vxl_index_count,
			GL_UNSIGNED_INT,
			((GLushort *)0));
		glBindVertexArray(0);

		SDL_GL_SwapWindow(window);
		usleep(100);
		int curframe_time = SDL_GetTicks();
		frame_counter++;
		if(curframe_time >= nextframe_time) {
			printf("%4d FPS\n", frame_counter);
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

