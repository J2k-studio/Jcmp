# Packaging an app: `makej apk`, `apkj`, `pack`, `dist`

This guide shows how a J2K program becomes an Android app (`.apk`) or a Jaric package (`.jc`).
What was run is marked as such: `makej init -apk` and `makej apk` were run on the author's phone
(2026-11-05, with the Android build tools that Termux has). Installing the app on the phone was **not**
run, and `apkj` is not installed here, so its steps are from the tutorial (lesson 85) and were not run.

## 1. Start an app

```
makej init -apk MyApp
cd MyApp
makej            # checks that the app compiles
makej apk        # builds _out/MyApp.apk
```

`makej init -apk` writes this project (run):

```
MyApp/
  makej            the build file: a library [library.myapp] with -l
  manifest.toml    what the app is (name, id, version, render, orientation)
  README.md
  src/main.jk      the app: which page shows, and what a touch does
  src/ui/          the small parts every page uses (button, title)
  src/pages/       one file for each page (home.jk, about.jk, notes.jk)
  assets/          pictures and sounds that go into the apk
  data/            what the app keeps
```

The app is a shared library (`libgame.so`) that an Android activity calls. `<glapp>` gives it the
surface, touches and keys; `<canvas2d>` draws; `<ui>` makes buttons and titles. The template's comment
says to install the libraries with `jc lib install glapp canvas2d glcanvas opengl3`.

## 2. `manifest.toml`

The file the template writes (run):

```
# the manifest of the app (like AndroidManifest.xml): makej apk reads it
name = "MyApp"
id = "com.example.myapp"
version = "0.1.0"
type = "app"
render = "gl"
main = "src/main.jk"
orientation = "portrait"
```

| Key | Used for | Rule (from `makej`) |
|---|---|---|
| `name` | the label under the icon, the file name | required |
| `id` | the package name | required; it must contain a dot (`com.you.myapp`) |
| `version` | the version name | required; `versionCode` = major * 10000 + minor * 100 + patch (`0.1.0` gives 100, checked) |
| `render` | `"gl"`: the app draws with OpenGL ES itself | `"gl"` needs `main` (the game file) |
| `main` | the file that is compiled into `libgame.so` | default `src/main.jk` |
| `orientation` | `portrait`, `landscape` ... | sets `android:screenOrientation` |

`minSdkVersion` and `targetSdkVersion` are **not** in the manifest: `makej` writes them into the
`AndroidManifest.xml` it makes. With the Android tools (`aapt2`) the values are 29 (minimum) and 28
(target), checked with `aapt2 dump badging`. A target of 28 is an old level: check it before an app is
published anywhere.

## 3. `makej apk`: the Android tools route

With `aapt2`, `ecj`, `d8`, `zipalign`, `apksigner` and `keytool` installed (Termux has all six),
`makej apk` runs the steps itself (run):

```
$ makej apk
makej: built _out/MyApp.apk (135683 bytes). Install: cp _out/MyApp.apk /sdcard/ and open it, or  pm install -r _out/MyApp.apk
```

What was checked on the result:

```
$ apksigner verify _out/MyApp.apk        # exit code 0
$ apksigner verify --print-certs _out/MyApp.apk
V3.0 Signer: certificate DN: CN=Jaric debug
$ aapt2 dump badging _out/MyApp.apk
package: name='com.example.myapp' versionCode='100' versionName='0.1.0' ...
minSdkVersion:'29'
targetSdkVersion:'28'
uses-permission: name='android.permission.INTERNET'
$ unzip -l _out/MyApp.apk
  AndroidManifest.xml   resources.arsc   classes.dex
  lib/arm64-v8a/libgame.so
  META-INF/JARIC.SF   META-INF/JARIC.RSA   META-INF/MANIFEST.MF
```

So an apk has the manifest, a small `classes.dex` (the Java part that starts your library), your
`libgame.so`, and the signature. `libgame.so` is stored without compression (`zip -0`).

**Signing (this route).** `makej` signs with a debug key: `~/.jaric-debug.keystore` (RSA 2048), created
the first time with a fixed password. Set `MAKEJ_KEYSTORE=path` to use another keystore. A debug key is
for testing; an app that is updated on the phone must keep the same key, and a release key is not
described in these docs.

## 4. `apkj`: an apk without the Android tools (not run here)

`apkj` is a tool written in J2K. It makes the manifest, the dex, the zip and the signature itself
(ECDSA P-256 with its own certificate), so no `aapt2`, `ecj`, `d8`, `zipalign`, `apksigner`, `keytool`
or `android.jar` are needed. Tutorial lesson 85:

```
apkj key                                                   # makes ~/.apkj.key once; keep it
apkj build manifest.toml MyApp.apk lib/arm64-v8a/libgame.so=_out/libgame.so assets/data/hello.txt=assets/hello.txt
apkj manifest manifest.toml AndroidManifest.xml            # only the manifest (binary XML)
```

`makej apk` uses `apkj` when `MAKEJ_APKJ=1` is set, or when Android tools are missing and the app has
`render = "gl"` and no `icon.png`. Keep one way per app: an update must be signed with the same key.
`apkj` is not installed on the author's phone (`command -v apkj` found nothing), so these lines are
not run in this guide. The tutorial says it is installed with `jc install apkj`.

## 5. Running the apk (not run here)

The makej output suggests `cp _out/MyApp.apk /sdcard/` and opening it, or `pm install -r _out/MyApp.apk`.
Neither was run: installing on the author's phone was not part of this check. A native library is loaded
by the app's `System.loadLibrary`; the library's exported functions are the ones the template calls
(`game_init`, `game_resize`, `game_frame`, `game_touch`, see `src/main.jk`).

## 6. `makej pack` and `makej dist` (not run here)

| Command | Makes | Notes |
|---|---|---|
| `makej pack` | `NAME.jc` | a zip with `manifest.toml`, the program and `assets/`, made by the step `zipj` in the game template; the package of Jaric OS |
| `makej dist` | every system in `manifest.toml` (`os = "android jaric linux"`) | calls `apk` for android, `pack` for jaric |
| `makej targets` | the systems the project can build for | |
| `makej init -game` | a game with Jaric Engine and five lessons | `makej apk` and `makej pack` apply to it too |

The makej source says the `.jc` program is ARM64 today. These commands were not run here (the game
template and `zipj` were not used in this check).

## 7. Checklist before a build

1. `makej` compiles the app without errors (warnings are printed; they are not hidden).
2. `manifest.toml` has `name`, `id` (with a dot), `version`.
3. `makej apk` prints `built _out/NAME.apk`.
4. `apksigner verify _out/NAME.apk` says it verifies (exit code 0).
5. `aapt2 dump badging _out/NAME.apk` shows the name, the version and the SDK values you expect.

## See also

* [UI.md](UI.md) for `<ui>` and the pages of an app
* [GPU.md](GPU.md) for `<glapp>`, `<canvas2d>` and OpenGL ES
* [BUILD.md](BUILD.md) for `makej` in general and the build file
* [INTEROP.md](INTEROP.md) for loading a J2K library from Java (JNI)
