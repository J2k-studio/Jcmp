// glapp 0.1.0 -- a game that is a shared library inside an Android app: the app (a GLSurfaceView) owns the screen and the OpenGL ES context
// and calls the game on its GL thread.   #import <glapp>   build: jcmp game.jk -l -o libgame.so   (makej with  render = "gl"  in manifest.toml does it all)   (license: MPL-2.0)
// The game defines four functions (glapp calls them; they are found by name):
//   void game_init(int w, int h)                   // the surface exists (w x h dots): load pictures, make things
//   void game_resize(int w, int h)                 // the surface changed (the phone turned)
//   void game_frame(int ms)                        // draw one frame; ms since the last one. Draw with  Canvas2d^ c = glapp_canvas();  or  glapp_gl()  directly
//   void game_touch(int action, int x, int y, int id)      // action 1 down, 2 move, 3 up (the same numbers as the Jaric app); x, y in dots of the surface
// glapp_gl() is the Gl of the context the app made; glapp_canvas() the Canvas2d on it (<glcanvas>, ES 3 or ES 2); glapp_w() / glapp_h() the size.
// The functions below (Java_com_j2k_gamerun_GameLib_*) are the JNI entry points of the class GameLib that the app has; do not call them.
#import <opengl3>
#import <canvas2d>
#import <glcanvas>

Gl glapp_gl_v;
GlCanvas glapp_canvas_v;
int glapp_w_v;
int glapp_h_v;
int glapp_started;

Gl glapp_gl() { return glapp_gl_v; }
Canvas2d^ glapp_canvas() { return @glapp_canvas_v; }
int glapp_w() { return glapp_w_v; }
int glapp_h() { return glapp_h_v; }

export int Java_com_j2k_gamerun_GameLib_init(int env, int cls, int w, int h) {
    glapp_w_v = w;
    glapp_h_v = h;
    glapp_gl_v = Gl::attach(w, h);
    if !glapp_gl_v.ok { return 0; }
    glapp_canvas_v.init();
    glapp_canvas_v.setup(glapp_gl_v, (double)w, (double)h);
    if !glapp_canvas_v.ready { return 0; }
    glapp_started = 1;
    game_init(w, h);
    return 1;
}

export void Java_com_j2k_gamerun_GameLib_resize(int env, int cls, int w, int h) {
    glapp_w_v = w;
    glapp_h_v = h;
    if glapp_started == 0 { return; }
    glapp_canvas_v.w = (double)w;
    glapp_canvas_v.h = (double)h;
    glapp_gl_v.resize(w, h);
    game_resize(w, h);
}

export void Java_com_j2k_gamerun_GameLib_frame(int env, int cls, int ms) {
    if glapp_started == 0 { return; }
    game_frame(ms);
}

export void Java_com_j2k_gamerun_GameLib_touch(int env, int cls, int action, int x, int y, int id) {
    if glapp_started == 0 { return; }
    game_touch(action, x, y, id);
}
