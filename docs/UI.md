# Screens of an app with `<ui>`

`<ui>` (jc lib install ui) draws buttons, labels, switches and sliders over `<canvas2d>`. It is *immediate mode*: you call the widgets
every frame, from the top down, in the order you want to see them; a widget draws itself and tells you what happened. There is no
tree of objects to build and nothing to keep in step with your data.

## The smallest app

`makej init -apk MyApp` makes the project; the screen code goes in `src/main.jk`:

```jk
#import <stdlib>
#import <glapp>
#import <ui>

Ui u;
bool sound;
double speed;
int taps;

void game_init(int w, int h) { u.start(); sound = true; speed = 5.0; }
void game_resize(int w, int h) { }
void game_touch(int action, int x, int y, int id) { u.touch(action, x, y); }

void game_frame(int ms) {
    Canvas2d^ c = glapp_canvas();
    c^.begin();
    c^.clear(u.th.bg);
    u.begin(c, (double)glapp_w(), (double)glapp_h());
    u.title("MY APP");
    u.label("TAPS " + str(taps));
    if u.button("TAP ME") { taps += 1; }
    u.toggle("SOUND", @sound);
    u.slider("SPEED", @speed, 0.0, 10.0);
    u.cols(2);
    if u.button("RESET") { taps = 0; }
    if u.button("MAX") { speed = 10.0; }
    u.end_cols();
    u.end();
    c^.end();
}
```

## The widgets

| call | what it does |
|---|---|
| `u.title("TEXT")` | the bar at the top; the widgets start under it |
| `u.label("TEXT")` | a line of text |
| `u.button("TEXT")` | a button; returns `true` in the frame where the finger goes up inside the box it went down on |
| `u.toggle("TEXT", @flag)` | a switch; a tap changes `flag`; returns `true` when it changed |
| `u.slider("TEXT", @value, lo, hi)` | follows the finger from `lo` to `hi`; returns `true` when `value` changed |
| `u.cols(n)` ... `u.end_cols()` | the widgets in between stand side by side in `n` equal columns |
| `u.spacer(40.0)` | empty space |

A tap that goes down on a button and up somewhere else does not click it (the user can change their mind). Colours and sizes are in
`u.th` (`bg panel accent hot text dim`, `pad gap row_h scale`); change them after `u.start()`.

## Text

For now the text is the 3 x 5 font of `canvas_text`: capital letters, digits and signs (lower case is shown as capitals by `upper()`). A font
with lower case letters and Thai is planned; the drawing goes through `u.text(x, y, s, colour)`, so it changes in one place.

## Pages

A page is a function that calls widgets and returns the number of the page to go to (or -1 to stay):

```jk
int page;
int home(Ui^ u) {
    u^.title("HOME");
    if u^.button("ABOUT") { return 1; }
    return -1;
}
int about(Ui^ u) {
    u^.title("ABOUT");
    u^.label("MADE WITH J2K");
    if u^.button("BACK") { return 0; }
    return -1;
}
// in game_frame, between u.begin and u.end:
//   int go = -1;
//   if page == 0 { go = home(@u); } else { go = about(@u); }
//   if go >= 0 { page = go; }
```

## Testing without a phone

`Ui` draws on a `Canvas2d`, an interface; give it a pretend canvas that only counts what is drawn (see `test/t573_ui.jk`) and call
`u.touch(1, x, y)` then `u.touch(3, x, y)` between frames to tap. The test taps a button, a switch, a slider and two columns.
