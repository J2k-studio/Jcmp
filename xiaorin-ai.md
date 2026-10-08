# Xiaorin — AI Context Spec

PROJECT: Xiaorin. Android assistant app, replaces Huawei Assistant. Full ecosystem, not standalone AI.
DEVICE: Huawei P40 5G, Kirin 990 5G, EMUI12/Android10 base, no root.
BUILD: Termux-only (no PC). ECJ (Java7 compliance, no lambdas), aapt2, d8, apksigner, NDK. compileSdk=34, min/targetSdk=29.
STATUS: codebase reset to bare skeleton (manifest + empty MainActivity). Rebuilding from zero.
PACKAGING: single APK, all sub-apps as internal modules/activities (not separate installs).

## MODULES (build order)

1. CORE: always-on background service (microG-style, no GMS). Voice+text input via custom rule-based NLU/intent parser. Full device control. In-app terminal. Half-screen summon UI.
2. USER_SYSTEM: signup -> login flow. Local state in `config.local` (key=value file). Backup/restore via GitHub Contents REST API (no git binary).
3. ENV: sandbox (isolated-thread exec) + custom scripting engine (line-based, own syntax) + virtual filesystem container, combined. Time-based trigger/automation (daily scheduled scripts).
4. ASSISTANT_FEATURES: music player, alarms, calendar, realtime translation, web/file search, camera (photo + QR scan, max HW use of ISP/NPU/GPU), notification summarization, battery/storage alerts, code error-log analysis, terminal autocomplete, NL file management, routine learning, voice/face/passphrase lock, 3D animated character UI, Dynamic Island-style notification overlay, status-bar quick tile, daily usage summary, self-debug logging, study tools (slide summarization, exam quiz, focus tracking), IoT/Bluetooth control.
5. ECOSYSTEM (same APK): Coderin (code editor/IDE), XiaoMotion (video editor), game engine, offline visual environment.
6. OS_LAYER (separate from ENV, hardest/longest-term): "Jirai kernel" + "Jormony OS", self-written. ARM64 + ARM32 compat (matches Huawei's own arch approach). No KVM available on-device (no root, EMUI blocks AVF) -> must be software full-system emulation, custom CPU emulator written from scratch (not QEMU-based), compiled as native lib via NDK.

## CONSTRAINTS
- No lambdas / no Java8+ syntax (ECJ wrapper is hardcoded `-7` compliance; use anonymous inner classes).
- R class: cross-package references need explicit `import com.xiaorin.R;` (aapt2 only generates R.java at manifest's top package).
- No external libraries beyond what's bundled in android.jar (org.json, android.util.Base64 OK to use).
- AI model/training is handled solely by the user (Jaooo); Claude's scope = app engineering only.
- Rule: do not add anything to this plan unless the user explicitly says to.
- Update this plan on every bug fix / completed milestone.
- UX/UI design deferred to a later planning pass.
