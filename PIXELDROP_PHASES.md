# Pixeldrop — Phased Build Plan for Claude Code

> **How to use this document**
> This file lives at the root of the `pixeldrop/` repo and is the single source of truth for the build.
> To start a phase, tell Claude Code: `Read PIXELDROP_PHASES.md in full. Then build Phase N. Do not continue to Phase N+1.`
> Work through each phase in order. Complete every checklist item before moving to the next phase.
> Each phase ends with a verification step — do not proceed until it passes.

---

## Overview

| Phase | Name | Packages touched |
|-------|------|-----------------|
| 0 | Repository Initialisation | root |
| 1 | Monorepo & Shared Foundation | root, shared |
| 2 | Backend Core | backend |
| 3 | Backend Routes + End-to-End Smoke Test | backend |
| 4 | Frontend Data & Domain Layer | frontend |
| 5 | Frontend Presentation Layer | frontend |
| 6 | Polish, Performance & Colour Picker | frontend |
| 7 | Tests | shared, backend, frontend |
| 8 | Deployment & Configuration | root |

---

## Phase 0 — Repository Initialisation

> Goal: Empty repo exists, plan file is in place, git is initialised. Nothing is built yet.

### 0.1 Create the repository
- [x] Create root directory `pixeldrop/`
- [x] Initialise git: `git init`
- [x] Create `.gitignore` at the root with the following entries:
  ```
  # Dart / Flutter
  .dart_tool/
  build/
  *.g.dart
  *.freezed.dart
  .flutter-plugins
  .flutter-plugins-dependencies
  pubspec.lock

  # Backend env
  packages/backend/.env

  # Firebase
  .firebase/

  # IDE
  .DS_Store
  .idea/
  .vscode/
  *.iml

  # Build outputs
  /server
  ```

### 0.2 Add the plan file
- [x] Copy `PIXELDROP_PHASES.md` into the root of `pixeldrop/`
- [x] Make an initial commit:
  ```bash
  git add .
  git commit -m "chore: initialise repo and add build plan"
  ```

### ✅ Phase 0 verification
- [x] `git log --oneline` shows exactly one commit
- [x] `PIXELDROP_PHASES.md` exists at repo root
- [x] `.gitignore` exists at repo root
- [x] `git status` is clean

---

## Phase 1 — Monorepo & Shared Foundation

> Goal: Pub workspace boots cleanly. All shared models compile and round-trip through JSON.

### 1.1 Workspace scaffold
- [x] Create root directory `pixeldrop/`
- [x] Create root `pubspec.yaml` with pub workspace pointing to `packages/shared`, `packages/frontend`, `packages/backend`
  ```yaml
  name: pixeldrop
  environment:
    sdk: '>=3.11.0 <4.0.0'
  workspace:
    - packages/shared
    - packages/frontend
    - packages/backend
  ```
- [x] Create `packages/shared/` as a plain Dart package:
  ```bash
  dart create -t package packages/shared
  ```
  Then set `name: shared` in its `pubspec.yaml` and ensure sdk `>=3.11.0 <4.0.0`. Remove the example lib/src files.

- [x] Create `packages/frontend/` using Flutter with the correct org and project name:
  ```bash
  flutter create \
    --org dev.martinloeseth \
    --project-name pixeldrop \
    packages/frontend
  ```
  This sets the bundle identifier to `dev.martinloeseth.pixeldrop` on iOS/Android/macOS and the package name on Android. The directory will be `packages/frontend/` but the app's internal name is `pixeldrop`.
  After creation, open `packages/frontend/pubspec.yaml` and add the pub workspace `resolution: workspace` field.

- [x] Enable all target platforms for the Flutter app:
  ```bash
  cd packages/frontend
  flutter create --platforms=web,android,ios,macos,windows,linux .
  ```

- [x] Create `packages/backend/` as a Dart Frog project:
  ```bash
  dart pub global activate dart_frog_cli
  dart_frog create packages/backend
  ```
  Then set `name: backend` in its `pubspec.yaml`.

- [x] Add `resolution: workspace` to both `packages/shared/pubspec.yaml` and `packages/backend/pubspec.yaml` so they participate in the pub workspace.

- [x] Run `dart pub get` at root — confirm all three packages resolve without errors

### 1.2 Shared constants
- [x] Create `packages/shared/lib/constants.dart` with:
  - [x] `const int canvasWidth = 1000`
  - [x] `const int canvasHeight = 1000`
  - [x] `const int chunkSize = 250` — divides evenly into 1000, giving exactly 4×4 = 16 chunks, no partial edges
  - [x] `const int chunksX = 4` (1000 ÷ 250)
  - [x] `const int chunksY = 4` (1000 ÷ 250)
  - [x] `const int totalChunks = 16`
  - [x] `const Duration pixelCooldown = Duration(seconds: 5)`
  - [x] `const List<int> presetColours` — 16 ARGB ints matching r/place 2022 palette: dark red, red, orange, yellow, dark green, green, dark teal, teal, dark blue, blue, dark purple, purple, white, light grey, dark grey, black

### 1.3 Pixel model
- [x] Create `packages/shared/lib/models/pixel.dart`
  - [x] Immutable class `Pixel { final int x, y, color; }` (color = ARGB int)
  - [x] `toJson()` → `Map<String, dynamic>`
  - [x] `fromJson(Map<String, dynamic>)` factory
  - [x] `copyWith()`

### 1.4 Chunk model
- [x] Create `packages/shared/lib/models/chunk.dart`
  - [x] `ChunkKey` value object `{ int cx, int cy }`
    - [x] `factory ChunkKey.fromPixel(int x, int y)` — divides pixel coords by `chunkSize`
    - [x] `int get index => cy * chunksX + cx` — values 0–15 for a 4×4 grid
    - [x] `==` and `hashCode` based on `cx, cy`
  - [x] `Chunk` class `{ ChunkKey key, Uint32List pixels }`
    - [x] `pixels.length == chunkSize * chunkSize`
    - [x] `int getPixel(int localX, int localY)`
    - [x] `void setPixel(int localX, int localY, int argbColor)`
    - [x] `static Chunk white(ChunkKey key)` — initialises all pixels to `0xFFFFFFFF`
    - [x] `Uint8List toBytes()` — converts ARGB Uint32List to raw byte array
    - [x] `static Chunk fromBytes(ChunkKey key, Uint8List bytes)` — inverse of toBytes

### 1.5 WebSocket message protocol
- [x] Create `packages/shared/lib/models/ws_message.dart`
  - [x] Sealed class `WsMessage` with subtypes:
    - [x] `PixelUpdate { Pixel pixel, String userId }`
    - [x] `RateLimitError { int retryAfterMs }`
    - [x] `UserCount { int count }`
    - [x] `BatchUpdate { List<PixelUpdate> updates }` (for server-side batching in Phase 6)
  - [x] JSON encode with `type` discriminator field for each subtype
  - [x] `WsMessage.fromJson(Map<String, dynamic>)` factory that switches on `type`

### 1.6 Barrel export
- [x] Create `packages/shared/lib/shared.dart` exporting constants, all models

### ✅ Phase 1 verification
- [x] `dart analyze packages/shared` — zero errors, zero warnings
- [x] Write and run a quick inline test: construct each WsMessage subtype, encode to JSON, decode back, assert equality
- [x] `dart pub get` at root still succeeds after all files are added

---

## Phase 2 — Backend Core

> Goal: Canvas store, connection management, and rate limiting all work correctly in isolation.

### 2.1 Backend dependencies
- [x] Add to `packages/backend/pubspec.yaml`:
  ```yaml
  dependencies:
    dart_frog: ^1.2.6
    dart_frog_web_socket: ^1.0.3
    shared:
      path: ../shared
    uuid: ^4.4.0
    web_socket_channel: ^3.0.0
  ```
- [x] Run `dart pub get` in `packages/backend`

### 2.2 CanvasStore
- [x] Create `packages/backend/lib/canvas_store.dart`
  - [x] Hold full 1000×1000 canvas as `Uint32List` of size `canvasWidth * canvasHeight` (1,000,000 entries, ~4 MB)
  - [x] Index formula: `y * canvasWidth + x`
  - [x] Initialise all pixels to `0xFFFFFFFF` (white) in constructor
  - [x] `void setPixel(int x, int y, int color)` — clamp x/y to valid range, do not throw
  - [x] `int getPixel(int x, int y)`
  - [x] `Uint8List getChunkBytes(int cx, int cy)`
    - [x] Extract 250×250 region from the Uint32List
    - [x] Convert each pixel from ARGB int to 4 bytes in ARGB order
    - [x] All chunks are exactly 250×250 — no partial edge handling needed (1000 ÷ 250 = 4 exactly)
    - [x] Return `Uint8List` of exactly `chunkSize * chunkSize * 4` = 250,000 bytes

### 2.3 ConnectionManager
- [x] Create `packages/backend/lib/connection_manager.dart`
  - [x] `Map<String, WebSocketChannel> _connections` (private)
  - [x] `void add(String id, WebSocketChannel ch)`
  - [x] `void remove(String id)`
  - [x] `void broadcast(WsMessage msg)` — serialise to JSON string, sink to all channels
  - [x] `void sendTo(String id, WsMessage msg)` — send to a single connection by id
  - [x] `int get userCount => _connections.length`

### 2.4 RateLimiter
- [x] Create `packages/backend/lib/rate_limiter.dart`
  - [x] `Map<String, DateTime> _lastPlacement` (private)
  - [x] `bool isAllowed(String userId)` — true if userId unseen OR `DateTime.now() - _lastPlacement[userId] > pixelCooldown`
  - [x] `void record(String userId)` — store `DateTime.now()` for userId
  - [x] `int retryAfterMs(String userId)` — returns remaining cooldown in milliseconds
  - [x] `void cleanup()` — remove all entries where last placement > `2 * pixelCooldown` ago

### 2.5 Middleware (dependency injection)
- [x] Create `packages/backend/routes/_middleware.dart`
  - [x] `context.provide<CanvasStore>(() => CanvasStore())` — single instance
  - [x] `context.provide<ConnectionManager>(() => ConnectionManager())` — single instance
  - [x] `context.provide<RateLimiter>(() => RateLimiter())` — single instance
  - [x] Start `Timer.periodic(Duration(minutes: 1), (_) => rateLimiter.cleanup())`

### ✅ Phase 2 verification
- [x] `dart analyze packages/backend` — zero errors
- [x] Manually instantiate `CanvasStore`, call `setPixel(0, 0, 0xFF0000FF)`, assert `getPixel(0,0) == 0xFF0000FF`
- [x] Manually instantiate `CanvasStore`, call `getChunkBytes(0, 0)`, assert returned length is `250 * 250 * 4` = 250,000 bytes
- [x] Manually instantiate `RateLimiter`, call `isAllowed('user1')` twice in quick succession — first true, second false

---

## Phase 3 — Backend Routes + Smoke Test

> Goal: Server starts, chunk endpoint returns bytes, WebSocket accepts connections and broadcasts pixel updates.

### 3.1 Health route
- [ ] Create `packages/backend/routes/api/health.dart`
  - [ ] `GET /api/health` returns `200 OK` with body `{"status": "ok"}`

### 3.2 Chunk REST route
- [ ] Create `packages/backend/routes/api/chunk/[cx]/[cy].dart`
  - [ ] Parse `cx` and `cy` from path parameters as `int`
  - [ ] Validate: `cx` in `[0, 4)` and `cy` in `[0, 4)` — return `400` if invalid
  - [ ] Call `canvasStore.getChunkBytes(cx, cy)`
  - [ ] Return `Response` with:
    - [ ] Body: raw bytes (always exactly 250,000 bytes)
    - [ ] Header `Content-Type: application/octet-stream`
    - [ ] Header `Cache-Control: no-store`

### 3.3 WebSocket route
- [ ] Create `packages/backend/routes/ws/canvas.dart`
  - [ ] Use `webSocketHandler` from `dart_frog_web_socket`
  - [ ] **On connect:**
    - [ ] Generate UUID v4 as connection id
    - [ ] Call `connectionManager.add(id, channel)`
    - [ ] Broadcast `UserCount(connectionManager.userCount)` to all
  - [ ] **On message:**
    - [ ] Parse JSON → `WsMessage.fromJson`
    - [ ] Assert type is `PixelUpdate` — ignore anything else silently
    - [ ] Validate `pixel.x` in `[0, 1000)` and `pixel.y` in `[0, 1000)` — if invalid, return silently
    - [ ] Check `rateLimiter.isAllowed(userId)`:
      - If **blocked**: `connectionManager.sendTo(id, RateLimitError(retryAfterMs))` and return
    - [ ] `canvasStore.setPixel(pixel.x, pixel.y, pixel.color)`
    - [ ] `rateLimiter.record(userId)`
    - [ ] `connectionManager.broadcast(PixelUpdate(pixel, userId))`
  - [ ] **On disconnect:**
    - [ ] `connectionManager.remove(id)`
    - [ ] Broadcast `UserCount(connectionManager.userCount)` to all

### 3.4 Root index route
- [ ] Create `packages/backend/routes/index.dart` — return `200` with `{"app": "pixeldrop"}` (basic liveness)

### ✅ Phase 3 verification
- [ ] `dart_frog dev` starts without errors in `packages/backend`
- [ ] `curl http://localhost:8080/api/health` returns `{"status": "ok"}`
- [ ] `curl http://localhost:8080/api/chunk/0/0` returns binary data (250×250×4 = 250,000 bytes)
- [ ] `curl http://localhost:8080/api/chunk/4/4` returns HTTP 400 (out of bounds — valid range is 0–3)
- [ ] Connect two WebSocket clients to `ws://localhost:8080/ws/canvas`
  - [ ] Both receive `UserCount(2)` on the second connection
  - [ ] Send `PixelUpdate` JSON from client 1 — confirm client 2 receives the broadcast
  - [ ] Send second `PixelUpdate` from client 1 within 5s — confirm client 1 receives `RateLimitError`

---

## Phase 4 — Frontend Data & Domain Layer

> Goal: Flutter app connects to the backend, loads chunks via HTTP, receives live pixel deltas via WebSocket, and manages state correctly — no UI yet beyond a placeholder screen.

### 4.1 Frontend dependencies
- [ ] Add to `packages/frontend/pubspec.yaml`:
  ```yaml
  dependencies:
    flutter_riverpod: ^2.5.1
    riverpod_annotation: ^2.3.5
    web_socket_channel: ^3.0.0
    http: ^1.2.0
    shared_preferences: ^2.3.0
    uuid: ^4.4.0
    shared:
      path: ../shared
  dev_dependencies:
    riverpod_generator: ^2.4.0
    build_runner: ^2.4.0
    mocktail: ^1.0.0
  ```
- [ ] Run `flutter pub get` in `packages/frontend`

### 4.2 Core: Config
- [ ] Create `packages/frontend/lib/core/config.dart`
  - [ ] `const String wsUrl = String.fromEnvironment('WS_URL', defaultValue: 'ws://localhost:8080/ws/canvas')`
  - [ ] `const String apiBase = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080')`
  - [ ] `String chunkUrl(int cx, int cy) => '$apiBase/api/chunk/$cx/$cy'`

### 4.3 Core: UserIdentity
- [ ] Create `packages/frontend/lib/core/user_identity.dart`
  - [ ] On first call: generate UUID v4 and persist via `shared_preferences` under key `pixeldrop_user_id`
  - [ ] On subsequent calls: load from `shared_preferences`
  - [ ] `Future<void> init()` — must be called once at app startup
  - [ ] `String get userId` — synchronous getter after init

### 4.4 Data: WebSocketDatasource
- [ ] Create `packages/frontend/lib/features/canvas/data/websocket_datasource.dart`
  - [ ] Connect to `wsUrl` on construction
  - [ ] `Stream<WsMessage> get messages` — parses incoming JSON frames
  - [ ] `void sendPixelUpdate(int x, int y, int color, String userId)`
  - [ ] Auto-reconnect with exponential backoff: delays `[1s, 2s, 4s, 8s, 16s, 30s]`, then hold at 30s
  - [ ] `bool get isConnected`
  - [ ] `void dispose()` — close channel, cancel reconnect timers

### 4.5 Data: ChunkCache
- [ ] Create `packages/frontend/lib/features/canvas/data/chunk_cache.dart`
  - [ ] LRU cache, max 16 chunks (the entire 1000×1000 canvas fits in 16 chunks of 250×250 — ~4 MB total, well within device limits)
  - [ ] In practice the LRU cap means the full canvas can always be resident; eviction only matters if the cap is lowered in future for a larger canvas
  - [ ] Track insertion/access order using a `LinkedHashMap`
  - [ ] `Chunk? get(ChunkKey key)` — returns null on miss, updates access order on hit
  - [ ] `void put(ChunkKey key, Chunk chunk)` — evicts LRU entry if at capacity
  - [ ] `void markStale(ChunkKey key)` — flags chunk for re-fetch next time it's requested
  - [ ] `bool isStale(ChunkKey key)` — returns true if marked stale or not in cache
  - [ ] `void remove(ChunkKey key)`
  - [ ] `int get length`

### 4.6 Data: ChunkRepository
- [ ] Create `packages/frontend/lib/features/canvas/data/chunk_repository.dart`
  - [ ] Constructor takes `http.Client` and `ChunkCache`
  - [ ] `Future<Chunk> loadChunk(ChunkKey key)`
    - [ ] Return from cache if present and not stale
    - [ ] Otherwise: `GET chunkUrl(key.cx, key.cy)`
    - [ ] Parse response bytes → `Chunk.fromBytes(key, bytes)`
    - [ ] Store in cache and return
    - [ ] On HTTP error: throw descriptive exception
  - [ ] `void applyDelta(Pixel pixel)`
    - [ ] Compute `ChunkKey.fromPixel(pixel.x, pixel.y)`
    - [ ] Compute local coords: `localX = pixel.x % chunkSize`, `localY = pixel.y % chunkSize`
    - [ ] If chunk in cache (not stale): call `chunk.setPixel(localX, localY, pixel.color)`
    - [ ] If chunk not in cache: call `cache.markStale(key)`

### 4.7 Domain: CanvasState
- [ ] Create `packages/frontend/lib/features/canvas/domain/canvas_state.dart`
  - [ ] Plain Dart class (no freezed required, keep it simple):
    ```dart
    class CanvasState {
      final Map<ChunkKey, Chunk> loadedChunks;
      final Set<ChunkKey> loadingChunks;
      final int selectedColor;
      final int userCount;
      final bool isConnected;
      final Duration? cooldownRemaining;
      final String? errorMessage;
    }
    ```
  - [ ] `copyWith(...)` method

### 4.8 Domain: ViewportNotifier
- [ ] Create `packages/frontend/lib/features/canvas/domain/viewport_notifier.dart`
  - [ ] `@riverpod class ViewportNotifier extends Notifier<Rect>`
  - [ ] Initial state: `Rect.zero`
  - [ ] `void update(Rect visibleCanvasRect)` — updates state
  - [ ] `Set<ChunkKey> visibleChunks(Rect rect)` — computes all ChunkKeys whose bounds intersect `rect` plus a 1-chunk border for pre-loading. Maximum 16 keys total (4×4 grid).
  - [ ] `Set<ChunkKey> predictiveChunks(Rect prev, Rect current)` — adds 1 extra row/column in the direction of pan movement (clamped to grid bounds 0–3)

### 4.9 Domain: CanvasNotifier
- [ ] Create `packages/frontend/lib/features/canvas/domain/canvas_notifier.dart`
  - [ ] `@riverpod class CanvasNotifier extends AsyncNotifier<CanvasState>`
  - [ ] `build()`:
    - [ ] Await `UserIdentity.init()`
    - [ ] Start listening to `WebSocketDatasource.messages`
    - [ ] On `PixelUpdate`: call `chunkRepository.applyDelta`, emit updated state
    - [ ] On `UserCount`: update `userCount` in state
    - [ ] On `RateLimitError`: start cooldown countdown timer (see below)
    - [ ] Return initial `CanvasState` with `selectedColor = presetColours[0]`
  - [ ] `Future<void> onViewportChanged(Rect visibleCanvasRect)`:
    - [ ] Update `ViewportNotifier`
    - [ ] Compute chunks to load (visible + prefetch)
    - [ ] For each chunk not in `loadedChunks` and not in `loadingChunks`: mark as loading, call `chunkRepository.loadChunk`, on completion update state
    - [ ] Evict chunks that have been outside viewport for more than 30 seconds
  - [ ] `Future<void> placePixel(int x, int y)`:
    - [ ] Guard: if `cooldownRemaining != null` → do nothing
    - [ ] Optimistically apply pixel to local chunk in `loadedChunks`
    - [ ] Call `websocketDatasource.sendPixelUpdate(x, y, selectedColor, userId)`
  - [ ] `void selectColor(int argbColor)` — update `selectedColor` in state
  - [ ] Cooldown timer: on `RateLimitError`, start `Timer.periodic(Duration(seconds: 1))` decrementing `cooldownRemaining` until zero, then set to null

### 4.10 Providers barrel
- [ ] Create `packages/frontend/lib/shared/providers.dart`
  - [ ] Provide `http.Client` as a Riverpod provider
  - [ ] Provide `ChunkCache` as a Riverpod provider (singleton)
  - [ ] Provide `ChunkRepository` as a Riverpod provider
  - [ ] Provide `WebSocketDatasource` as a Riverpod provider

### ✅ Phase 4 verification
- [ ] `flutter analyze packages/frontend` — zero errors
- [ ] Run `build_runner` to generate Riverpod code — no generation errors
- [ ] Write a manual integration test: start backend from Phase 3, run frontend against it, confirm `CanvasNotifier` state transitions from `loading` to a non-empty `loadedChunks` after `onViewportChanged` is called with a non-zero rect
- [ ] Confirm `placePixel` sends a WebSocket message visible in backend logs
- [ ] Confirm `RateLimitError` triggers cooldown state correctly

---

## Phase 5 — Frontend Presentation Layer

> Goal: A working, interactive canvas that renders chunks, handles tap-to-place, panning, zooming, and displays a basic colour bar. No polish yet.

### 5.1 App entry point
- [ ] Create `packages/frontend/lib/main.dart`
  - [ ] Wrap app in `ProviderScope`
  - [ ] Await `UserIdentity.init()` before `runApp`
- [ ] Create `packages/frontend/lib/app.dart`
  - [ ] `MaterialApp` with `CanvasPage` as home route
  - [ ] Import theme from `core/theme.dart` (dark theme, black background)

### 5.2 Theme
- [ ] Create `packages/frontend/lib/core/theme.dart`
  - [ ] Dark `ThemeData` — black scaffold background, no app bar on canvas page
  - [ ] Colour scheme that does not clash with the pixel canvas

### 5.3 CanvasPainter
- [ ] Create `packages/frontend/lib/features/canvas/presentation/canvas_painter.dart`
  - [ ] `CustomPainter` that accepts `Map<ChunkKey, Chunk> loadedChunks` and optionally a transform
  - [ ] For each of the 16 chunks: draw its `ui.Image` at `Offset(key.cx * chunkSize, key.cy * chunkSize)` — each chunk occupies a 250×250 pixel region
  - [ ] For unloaded chunks: draw a `Rect` filled with `Color(0xFFCCCCCC)` (light grey placeholder)
  - [ ] `Map<ChunkKey, ui.Image?> _imageCache` (internal to painter)
    - [ ] When a chunk is new or dirty: call `_buildImage(chunk)` asynchronously using `decodeImageFromPixels` with `PixelFormat.rgba8888` (convert ARGB → RGBA during encode)
    - [ ] On image ready: store in `_imageCache`, call `markNeedsPaint()`
  - [ ] When zoom scale > 20×: draw a 1px semi-transparent grid overlay aligned to pixel boundaries
  - [ ] `shouldRepaint`: return `true` when `loadedChunks` reference changes

### 5.4 CanvasPage
- [ ] Create `packages/frontend/lib/features/canvas/presentation/canvas_page.dart`
  - [ ] `ConsumerStatefulWidget`
  - [ ] `TransformationController _controller` for `InteractiveViewer`
  - [ ] `_controller.addListener(...)` — debounced 100ms — computes visible canvas rect from matrix and calls `canvasNotifier.onViewportChanged(rect)`
    - [ ] Visible rect formula: apply inverse of transformation matrix to screen bounds, clamp to `[0, canvasWidth] × [0, canvasHeight]`
  - [ ] `InteractiveViewer`:
    - [ ] `minScale`: computed as `min(screenWidth / canvasWidth, screenHeight / canvasHeight)`
    - [ ] `maxScale: 40.0`
    - [ ] `constrained: false`
    - [ ] `boundaryMargin: EdgeInsets.zero`
    - [ ] Child: `SizedBox(width: 1000, height: 1000, child: CustomPaint(painter: CanvasPainter(...)))`
  - [ ] `GestureDetector` wrapping `InteractiveViewer`:
    - [ ] `onTapUp`: convert `localPosition` → canvas coords via `_controller.toScene(offset)`, call `canvasNotifier.placePixel(x.toInt(), y.toInt())`
    - [ ] `onLongPressStart`: show `PixelInfoOverlay` at tapped canvas coord
  - [ ] `Stack` layout:
    - [ ] `[0]` `InteractiveViewer` (fills screen)
    - [ ] `[1]` `Positioned(bottom: 0)` → `ColourPickerBar`
    - [ ] `[2]` `Positioned(top: 16, right: 16)` → `ZoomControls`
    - [ ] `[3]` `Positioned(bottom: 80, right: 16)` → `MinimapWidget`
    - [ ] `[4]` `Positioned(top: 16, left: 16)` → connection status + user count badge

### 5.5 ColourPickerBar (basic)
- [ ] Create `packages/frontend/lib/features/canvas/presentation/widgets/colour_picker_bar.dart`
  - [ ] Horizontal `Row` of 9 colour circles, 40px diameter each
  - [ ] Selected circle: white `3px` border ring + `1.2×` scale animation
  - [ ] Tapping a circle calls `canvasNotifier.selectColor(argbColor)`
  - [ ] During cooldown: show `CircularProgressIndicator` overlaid on selected colour circle, sized to match the circle
  - [ ] "+" `IconButton` at end — placeholder for Phase 6 dialog

### 5.6 ZoomControls
- [ ] Create `packages/frontend/lib/features/canvas/presentation/widgets/zoom_controls.dart`
  - [ ] `+` button: multiply current scale by 1.5, animate via `_controller.value`
  - [ ] `−` button: divide current scale by 1.5
  - [ ] `⌂` button: reset to fit-whole-canvas scale
  - [ ] Text label showing current zoom as `"42%"` or `"3.2×"` depending on scale

### 5.7 MinimapWidget
- [ ] Create `packages/frontend/lib/features/canvas/presentation/widgets/minimap_widget.dart`
  - [ ] Fixed size `120×120` (square — matches the 1:1 aspect of a 1000×1000 canvas)
  - [ ] `CustomPaint` that renders the 4×4 chunk grid (16 cells total)
    - [ ] For each loaded chunk: compute average colour of its pixels, fill corresponding minimap cell (each cell is 30×30 px within the minimap)
    - [ ] For unloaded chunks: fill with `Color(0xFFDDDDDD)`
  - [ ] White `Rect` overlay showing current viewport position — update on `TransformationController` changes
  - [ ] `GestureDetector.onTapUp`: pan canvas to tapped canvas position (update `_controller.value`)
  - [ ] Semi-transparent dark background with rounded corners

### 5.8 PixelInfoOverlay
- [ ] Create `packages/frontend/lib/features/canvas/presentation/widgets/pixel_info_overlay.dart`
  - [ ] Shows on `longPressStart`, auto-dismisses after 2 seconds
  - [ ] Displays: `(x, y)` canvas coordinates, colour hex string (e.g. `#FF0066`)
  - [ ] Small tooltip card, positioned near the long-pressed pixel

### ✅ Phase 5 verification
- [ ] App runs on Chrome (`flutter run -d chrome`) and connects to local backend
- [ ] Canvas renders grey placeholders on launch, then chunks fill in as viewport stabilises
- [ ] Panning loads new chunks (observe network requests in DevTools)
- [ ] Tapping a pixel sends a WebSocket message and the pixel updates in all connected clients
- [ ] Zooming in past 20× shows the pixel grid overlay
- [ ] Cooldown bar appears after placing a pixel and counts down
- [ ] Minimap shows correct viewport rectangle as you pan
- [ ] App runs on mobile (`flutter run -d <device>`) without layout overflow errors

---

## Phase 6 — Polish, Performance & Colour Picker

> Goal: Full colour picker, responsive layout, WebSocket batching, predictive pre-fetching, and image cache optimisation.

### 6.1 ColourPickerDialog
- [ ] Add dependency: `flex_color_picker: ^3.5.0`
- [ ] Create `packages/frontend/lib/features/colour_picker/colour_picker_dialog.dart`
  - [ ] Modal bottom sheet on mobile, `Dialog` on desktop
  - [ ] HSV colour wheel via `flex_color_picker`
  - [ ] Hex input field (`TextField`) with 6-char validation and live colour preview swatch
  - [ ] "Recently used" row — last 8 custom colours, persisted in `shared_preferences`
  - [ ] Confirm button: calls `canvasNotifier.selectColor(argbColor)` and pops
- [ ] Wire "+" button in `ColourPickerBar` to open this dialog

### 6.2 Responsive layout
- [ ] In `canvas_page.dart`, use `LayoutBuilder` to switch between layouts:
  - [ ] **Mobile** (`width < 600`):
    - Colour bar: `Positioned(bottom: 0)`, horizontal
    - Zoom controls: `Positioned(top: 16, right: 16)`
    - Minimap: `Positioned(bottom: 72, right: 8)`
  - [ ] **Desktop/Web** (`width >= 600`):
    - Colour bar: `Positioned(left: 0, top: 0, bottom: 0)`, vertical column
    - Zoom controls: `Positioned(top: 16, right: 16)`
    - Minimap: `Positioned(bottom: 16, right: 16)`
    - Status bar: `Positioned(bottom: 0, left: 64, right: 0)` — user count + connection indicator + coordinates under cursor

### 6.3 WebSocket message batching (backend)
- [ ] In `packages/backend/routes/ws/canvas.dart`:
  - [ ] Add `List<PixelUpdate> _pendingBroadcasts = []`
  - [ ] Add `Timer? _flushTimer`
  - [ ] Instead of calling `connectionManager.broadcast` immediately: add to `_pendingBroadcasts`
  - [ ] Start `_flushTimer = Timer(Duration(milliseconds: 32), _flush)` if not already running
  - [ ] `_flush()`:
    - If 1 item: broadcast as single `PixelUpdate`
    - If 2+ items: broadcast as `BatchUpdate { updates: _pendingBroadcasts }`
    - Clear list and reset timer
- [ ] In `packages/frontend/lib/features/canvas/data/websocket_datasource.dart`:
  - [ ] Handle `BatchUpdate` messages: emit each `PixelUpdate` in sequence (or apply all at once before notifying)

### 6.4 Predictive chunk pre-fetching
- [ ] In `viewport_notifier.dart`:
  - [ ] Track last two viewport rects (`_prevRect`, `_currentRect`)
  - [ ] `Set<ChunkKey> predictiveChunks()`:
    - Compute pan delta: `_currentRect.center - _prevRect.center`
    - If panning right: include 1 extra column of chunks to the right of visible area
    - If panning left: include 1 extra column to the left
    - If panning down: include 1 extra row below
    - If panning up: include 1 extra row above
- [ ] In `canvas_notifier.dart`: include `predictiveChunks()` in the set of chunks to load on viewport change

### 6.5 Image cache optimisation
- [ ] In `canvas_painter.dart`:
  - [ ] Batch `ui.Image` rebuilds: collect all dirty `ChunkKey`s during a frame, rebuild their images in a single `WidgetsBinding.instance.addPostFrameCallback`
  - [ ] Use `ui.ImmutableBuffer.fromUint8List` + `ui.ImageDescriptor.raw` + `instantiateCodec` for faster decode on Flutter Web (replaces `decodeImageFromPixels` which is slower on web)
  - [ ] When a chunk's `Uint32List` is updated via `applyDelta`, mark its `ui.Image` cache entry as dirty (remove from `_imageCache`)

### 6.6 Chunk eviction timing
- [ ] In `canvas_notifier.dart`:
  - [ ] Track `Map<ChunkKey, DateTime> _lastInViewport` timestamps
  - [ ] On each `onViewportChanged`: update timestamps for visible chunks
  - [ ] Run eviction check every 10 seconds via `Timer.periodic`
  - [ ] Evict chunks where `DateTime.now() - _lastInViewport[key] > Duration(seconds: 30)`
  - [ ] On evict: remove from `loadedChunks` in state and call `chunkCache.remove(key)`

### ✅ Phase 6 verification
- [ ] Colour picker dialog opens, hex input correctly previews colour, recently used row persists across sessions
- [ ] Desktop layout shows vertical colour bar without overflow
- [ ] Open browser DevTools Network tab: confirm multiple rapid pixel placements result in batched WS frames (not one frame per pixel)
- [ ] Observe chunk pre-fetching: when panning right, chunks to the right load before they enter the visible area
- [ ] Long session test: pan around extensively, confirm memory usage stays stable (LRU eviction working)

---

## Phase 7 — Tests

> Goal: Critical paths are covered with unit tests. All tests pass.

### 7.1 Shared package tests
- [ ] Create `packages/shared/test/ws_message_test.dart`
  - [ ] JSON round-trip: `PixelUpdate`, `RateLimitError`, `UserCount`, `BatchUpdate`
  - [ ] Unknown `type` in JSON throws or returns null (document the chosen behaviour)
- [ ] Create `packages/shared/test/chunk_test.dart`
  - [ ] `setPixel` / `getPixel` round-trip at corners: `(0,0)`, `(249,249)`, `(124,63)`
  - [ ] `toBytes` / `fromBytes` round-trip: encode a known pixel, decode, assert same value
  - [ ] `ChunkKey.fromPixel` correctness: pixel `(250, 0)` → `ChunkKey(1, 0)`, pixel `(0, 250)` → `ChunkKey(0, 1)`, pixel `(999, 999)` → `ChunkKey(3, 3)`
  - [ ] All 16 chunks are full-size (250×250) — no partial/edge chunks exist for 1000×1000 canvas

### 7.2 Backend tests
- [ ] Create `packages/backend/test/canvas_store_test.dart`
  - [ ] `setPixel(0, 0, color)` → `getPixel(0, 0) == color`
  - [ ] `setPixel(-1, 0, color)` — does not throw, does not corrupt adjacent pixel
  - [ ] `getChunkBytes(0, 0)` → length is `250 * 250 * 4` = 250,000 bytes
  - [ ] `getChunkBytes(3, 3)` (last chunk, still full-size since 1000 ÷ 250 = 4 exactly) → length is still 250,000 bytes
  - [ ] Pixel set at `(100, 100)` (chunk 0,0) is retrievable via `getChunkBytes(0, 0)` at expected byte offset
  - [ ] Pixel set at `(500, 500)` (chunk 2,2) is retrievable via `getChunkBytes(2, 2)` at local offset `(0, 0)` within that chunk
- [ ] Create `packages/backend/test/rate_limiter_test.dart`
  - [ ] First call to `isAllowed('user1')` → true
  - [ ] Immediately call `isAllowed('user1')` again → false
  - [ ] `record` + wait for cooldown duration (use `FakeAsync` or injectable clock) → `isAllowed` returns true again
  - [ ] `cleanup()` removes entries older than `2 * pixelCooldown`
- [ ] Create `packages/backend/test/chunk_route_test.dart`
  - [ ] `GET /api/chunk/0/0` → status 200, content-type `application/octet-stream`, body length 250,000
  - [ ] `GET /api/chunk/3/3` → status 200, body length 250,000 (valid last chunk)
  - [ ] `GET /api/chunk/4/0` → status 400 (out of bounds)
  - [ ] `GET /api/chunk/0/4` → status 400 (out of bounds)
  - [ ] `GET /api/chunk/abc/0` → status 400

### 7.3 Frontend tests
- [ ] Create `packages/frontend/test/chunk_cache_test.dart`
  - [ ] Put 64 chunks — all retrievable
  - [ ] Put 65th chunk — LRU entry is evicted
  - [ ] `markStale` then `isStale` returns true
  - [ ] `get` on stale entry returns the chunk but `isStale` still true (caller decides whether to re-fetch)
- [ ] Create `packages/frontend/test/chunk_repository_test.dart`
  - [ ] Mock `http.Client` — `loadChunk` calls GET and parses response bytes into `Chunk`
  - [ ] Second call for same key returns cached chunk without HTTP call
  - [ ] After `markStale`, next `loadChunk` makes a new HTTP call
  - [ ] `applyDelta` on loaded chunk updates the pixel in cache
  - [ ] `applyDelta` on unloaded chunk calls `markStale` (no HTTP call)
- [ ] Create `packages/frontend/test/canvas_notifier_test.dart`
  - [ ] Mock `WebSocketDatasource` and `ChunkRepository`
  - [ ] `onViewportChanged` with non-empty rect triggers `loadChunk` for visible chunks
  - [ ] `PixelUpdate` message from WS calls `applyDelta` and updates state
  - [ ] `placePixel` sends WS message and optimistically updates `loadedChunks`
  - [ ] `placePixel` during cooldown does nothing
  - [ ] `RateLimitError` message sets `cooldownRemaining` and counts down to null
- [ ] Create `packages/frontend/test/viewport_notifier_test.dart`
  - [ ] `visibleChunks` for rect covering top-left 500×500 pixels → `{ChunkKey(0,0), ChunkKey(1,0), ChunkKey(0,1), ChunkKey(1,1)}` plus 1-chunk border (clamped to grid)
  - [ ] `visibleChunks` for full canvas rect (0,0,1000,1000) → all 16 chunk keys
  - [ ] Panning right by 300px → `predictiveChunks` includes the column to the right (clamped to cx max of 3)

### ✅ Phase 7 verification
- [ ] `dart test packages/shared` — all tests pass
- [ ] `dart test packages/backend` — all tests pass
- [ ] `flutter test packages/frontend` — all tests pass
- [ ] Zero skipped tests

---

## Phase 8 — Deployment & Configuration

> Goal: The app builds and deploys via Docker (backend) and Firebase Hosting (frontend). Makefile covers all common dev and ops commands. GitHub Actions runs CI on every push and deploys on PR and merge to main.

### 8.1 Environment configuration
- [ ] Create `packages/backend/.env.example` (committed, no real values — documents required variables):
  ```
  HOST=0.0.0.0
  PORT=8080
  PIXEL_COOLDOWN_SECONDS=5
  MAX_CONNECTIONS=50000
  ```
- [ ] The actual `.env` is never committed — it is loaded into the shell environment before running the server (e.g. `export $(cat .env | xargs)` or via docker-compose `env_file`).
- [ ] The backend reads **all** config exclusively via `Platform.environment` — no `.env` parsing library. Example:
  ```dart
  import 'dart:io' show Platform;

  final host = Platform.environment['HOST'] ?? '0.0.0.0';
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final cooldownSeconds = int.parse(Platform.environment['PIXEL_COOLDOWN_SECONDS'] ?? '5');
  final maxConnections = int.parse(Platform.environment['MAX_CONNECTIONS'] ?? '50000');
  ```

### 8.2 .gitignore
- [ ] Create root `.gitignore` including:
  - [ ] `.env`, `.env.*`, `*.env` — all environment files are gitignored globally, never commit secrets
  - [ ] `build/`
  - [ ] `.dart_tool/`
  - [ ] `*.g.dart` (generated Riverpod files)
  - [ ] `.flutter-plugins`
  - [ ] `.flutter-plugins-dependencies`
  - [ ] `.firebase/`
  - [ ] `pubspec.lock` (packages only — keep frontend/backend lock files)

> **Note:** Any file matching `.env`, `.env.*`, or `*.env` is ignored at the repo root level.
> Use `.env.example` (committed, no real values) to document required variables.

### 8.3 Dockerfile (backend)
- [ ] Create `Dockerfile` at root:
  ```dockerfile
  FROM dart:stable AS build
  WORKDIR /app
  COPY . .
  RUN dart pub get
  RUN dart compile exe packages/backend/bin/server.dart -o /app/server

  FROM debian:bullseye-slim
  COPY --from=build /app/server /server
  EXPOSE 8080
  CMD ["/server"]
  ```

### 8.4 docker-compose.yml
- [ ] Create `docker-compose.yml` at root:
  ```yaml
  services:
    backend:
      build: .
      ports:
        - "8080:8080"
      environment:
        - PORT=8080
        - PIXEL_COOLDOWN_SECONDS=5
    frontend:
      image: nginx:alpine
      volumes:
        - ./packages/frontend/build/web:/usr/share/nginx/html
      ports:
        - "80:80"
      depends_on:
        - backend
  ```

### 8.5 Makefile
- [ ] Create `Makefile` at root with the following targets. Use `.PHONY` for all non-file targets. Each target must print a short description when run.

  ```makefile
  .PHONY: help dev-backend dev-frontend dev build-web build-backend \
          test test-shared test-backend test-frontend \
          lint lint-shared lint-backend lint-frontend \
          gen codegen \
          docker-build docker-up docker-down \
          firebase-login firebase-deploy-preview firebase-deploy

  # ── Help ────────────────────────────────────────────────────────────────────
  help:
  	@echo ""
  	@echo "  Pixeldrop — available make targets"
  	@echo ""
  	@echo "  Dev"
  	@echo "    make dev-backend       Start Dart Frog backend in watch mode"
  	@echo "    make dev-frontend      Run Flutter web app against local backend"
  	@echo "    make dev               Start backend + frontend in parallel"
  	@echo ""
  	@echo "  Build"
  	@echo "    make build-web         Flutter web release build (set WS_URL / API_URL)"
  	@echo "    make build-backend     AOT-compile backend to ./server binary"
  	@echo "    make codegen           Run build_runner for Riverpod code generation"
  	@echo ""
  	@echo "  Test & Lint"
  	@echo "    make test              Run all tests (shared + backend + frontend)"
  	@echo "    make lint              Analyze all packages"
  	@echo ""
  	@echo "  Docker"
  	@echo "    make docker-build      Build Docker image for backend"
  	@echo "    make docker-up         Start backend + nginx via docker compose"
  	@echo "    make docker-down       Stop and remove containers"
  	@echo ""
  	@echo "  Firebase"
  	@echo "    make firebase-login    Authenticate Firebase CLI"
  	@echo "    make firebase-deploy   Deploy web build to Firebase Hosting (production)"
  	@echo ""

  # ── Dev ─────────────────────────────────────────────────────────────────────
  dev-backend:
  	@echo "→ Starting Dart Frog backend..."
  	cd packages/backend && dart_frog dev

  dev-frontend:
  	@echo "→ Starting Flutter web (targeting local backend)..."
  	cd packages/frontend && flutter run -d chrome \
  	  --dart-define=WS_URL=ws://localhost:8080/ws/canvas \
  	  --dart-define=API_URL=http://localhost:8080

  dev:
  	@echo "→ Starting backend and frontend in parallel..."
  	$(MAKE) dev-backend & $(MAKE) dev-frontend

  # ── Build ────────────────────────────────────────────────────────────────────
  build-web:
  	@echo "→ Building Flutter web..."
  	cd packages/frontend && flutter build web \
  	  --dart-define=WS_URL=$${WS_URL:-wss://your-domain/ws/canvas} \
  	  --dart-define=API_URL=$${API_URL:-https://your-domain} \
  	  --release

  build-backend:
  	@echo "→ Compiling backend to AOT binary..."
  	dart pub get
  	dart compile exe packages/backend/bin/server.dart -o server

  codegen:
  	@echo "→ Running build_runner (Riverpod code generation)..."
  	cd packages/frontend && dart run build_runner build --delete-conflicting-outputs

  codegen-watch:
  	@echo "→ Watching for changes (Riverpod code generation)..."
  	cd packages/frontend && dart run build_runner watch --delete-conflicting-outputs

  # ── Test ─────────────────────────────────────────────────────────────────────
  test-shared:
  	@echo "→ Testing shared package..."
  	dart test packages/shared

  test-backend:
  	@echo "→ Testing backend package..."
  	dart test packages/backend

  test-frontend:
  	@echo "→ Testing frontend package..."
  	cd packages/frontend && flutter test

  test: test-shared test-backend test-frontend
  	@echo "✓ All tests passed."

  # ── Lint ─────────────────────────────────────────────────────────────────────
  lint-shared:
  	dart analyze packages/shared

  lint-backend:
  	dart analyze packages/backend

  lint-frontend:
  	cd packages/frontend && flutter analyze

  lint: lint-shared lint-backend lint-frontend
  	@echo "✓ Lint passed."

  # ── Docker ───────────────────────────────────────────────────────────────────
  docker-build:
  	@echo "→ Building Docker image..."
  	docker compose build

  docker-up:
  	@echo "→ Starting services via docker compose..."
  	docker compose up

  docker-down:
  	@echo "→ Stopping services..."
  	docker compose down

  # ── Firebase ─────────────────────────────────────────────────────────────────
  firebase-login:
  	firebase login

  firebase-deploy: build-web
  	@echo "→ Deploying to Firebase Hosting (production)..."
  	firebase deploy --only hosting
  ```

### 8.6 Firebase Hosting setup
- [ ] Install Firebase CLI globally: `npm install -g firebase-tools`
- [ ] Run `firebase login` to authenticate
- [ ] Run `firebase init hosting` in the repo root — select or create a Firebase project named `pixeldrop`
- [ ] When prompted by `firebase init`:
  - [ ] Public directory: `packages/frontend/build/web`
  - [ ] Configure as single-page app: **Yes** (rewrites all routes to `index.html`)
  - [ ] Set up automatic builds with GitHub: **No** (GitHub Actions will handle this)
  - [ ] Do not overwrite `index.html`
- [ ] This generates `firebase.json` and `.firebaserc` at the root — commit both
- [ ] Verify `firebase.json` looks like:
  ```json
  {
    "hosting": {
      "public": "packages/frontend/build/web",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [
        { "source": "**", "destination": "/index.html" }
      ]
    }
  }
  ```
- [ ] Add `FIREBASE_TOKEN` to GitHub repository secrets:
  - Run `firebase login:ci` locally → copy the token
  - In GitHub: Settings → Secrets and variables → Actions → New repository secret
  - Name: `FIREBASE_TOKEN`, value: the token from above
- [ ] Add `WS_URL` and `API_URL` to GitHub repository secrets for production values

### 8.7 GitHub Actions — CI workflow
- [ ] Create `.github/workflows/ci.yml`:
  ```yaml
  name: CI

  on:
    push:
      branches: ["**"]
    pull_request:
      branches: ["**"]

  jobs:
    analyze-and-test:
      name: Analyze & Test
      runs-on: ubuntu-latest

      steps:
        - name: Checkout
          uses: actions/checkout@v4

        - name: Setup Dart
          uses: dart-lang/setup-dart@v1
          with:
            sdk: stable

        - name: Setup Flutter
          uses: subosito/flutter-action@v2
          with:
            flutter-version: "3.22.x"
            channel: stable
            cache: true

        - name: Install dependencies
          run: dart pub get

        - name: Run build_runner (Riverpod codegen)
          run: |
            cd packages/frontend
            dart run build_runner build --delete-conflicting-outputs

        - name: Analyze — shared
          run: dart analyze packages/shared

        - name: Analyze — backend
          run: dart analyze packages/backend

        - name: Analyze — frontend
          run: cd packages/frontend && flutter analyze

        - name: Test — shared
          run: dart test packages/shared

        - name: Test — backend
          run: dart test packages/backend

        - name: Test — frontend
          run: cd packages/frontend && flutter test

        - name: Build Flutter web (smoke check)
          run: |
            cd packages/frontend && flutter build web \
              --dart-define=WS_URL=wss://placeholder/ws/canvas \
              --dart-define=API_URL=https://placeholder \
              --release
  ```

### 8.8 GitHub Actions — Firebase deploy workflow
- [ ] Create `.github/workflows/deploy.yml`:
  ```yaml
  name: Deploy

  on:
    # Deploy preview on every PR (open, sync, reopen)
    pull_request:
      types: [opened, synchronize, reopened]
      branches: [main]

    # Deploy to production on push/merge to main
    push:
      branches: [main]

  jobs:
    deploy-preview:
      name: Deploy Preview (PR)
      runs-on: ubuntu-latest
      if: github.event_name == 'pull_request'

      steps:
        - name: Checkout
          uses: actions/checkout@v4

        - name: Setup Flutter
          uses: subosito/flutter-action@v2
          with:
            flutter-version: "3.22.x"
            channel: stable
            cache: true

        - name: Setup Dart
          uses: dart-lang/setup-dart@v1
          with:
            sdk: stable

        - name: Install dependencies
          run: dart pub get

        - name: Run build_runner
          run: |
            cd packages/frontend
            dart run build_runner build --delete-conflicting-outputs

        - name: Build Flutter web
          run: |
            cd packages/frontend && flutter build web \
              --dart-define=WS_URL=${{ secrets.WS_URL }} \
              --dart-define=API_URL=${{ secrets.API_URL }} \
              --release

        - name: Deploy preview to Firebase Hosting
          uses: FirebaseExtended/action-hosting-deploy@v0
          with:
            repoToken: ${{ secrets.GITHUB_TOKEN }}
            firebaseServiceAccount: ${{ secrets.FIREBASE_TOKEN }}
            projectId: pixeldrop
            # Creates a unique preview channel per PR, expires after 7 days
            channelId: pr-${{ github.event.pull_request.number }}
            expires: 7d

    deploy-production:
      name: Deploy Production (main)
      runs-on: ubuntu-latest
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'

      steps:
        - name: Checkout
          uses: actions/checkout@v4

        - name: Setup Flutter
          uses: subosito/flutter-action@v2
          with:
            flutter-version: "3.22.x"
            channel: stable
            cache: true

        - name: Setup Dart
          uses: dart-lang/setup-dart@v1
          with:
            sdk: stable

        - name: Install dependencies
          run: dart pub get

        - name: Run build_runner
          run: |
            cd packages/frontend
            dart run build_runner build --delete-conflicting-outputs

        - name: Build Flutter web
          run: |
            cd packages/frontend && flutter build web \
              --dart-define=WS_URL=${{ secrets.WS_URL }} \
              --dart-define=API_URL=${{ secrets.API_URL }} \
              --release

        - name: Deploy to Firebase Hosting (production)
          uses: FirebaseExtended/action-hosting-deploy@v0
          with:
            repoToken: ${{ secrets.GITHUB_TOKEN }}
            firebaseServiceAccount: ${{ secrets.FIREBASE_TOKEN }}
            projectId: pixeldrop
            channelId: live
  ```

### ✅ Phase 8 verification
- [ ] `make help` — prints all targets with descriptions, no errors
- [ ] `make lint` — zero errors across all three packages
- [ ] `make test` — all tests pass
- [ ] `make codegen` — Riverpod files generated without conflicts
- [ ] `make dev-backend` — Dart Frog starts on port 8080
- [ ] `make dev-frontend` — Flutter web opens in Chrome and connects to local backend
- [ ] `make build-web WS_URL=wss://example.com/ws/canvas API_URL=https://example.com` — web build succeeds, output in `packages/frontend/build/web`
- [ ] `make docker-build` — Docker image builds successfully
- [ ] `make docker-up` — `curl http://localhost:8080/api/health` returns 200
- [ ] `firebase.json` and `.firebaserc` are committed and reference the correct project
- [ ] `FIREBASE_TOKEN`, `WS_URL`, `API_URL` are set in GitHub repository secrets
- [ ] Push a branch and open a PR → CI workflow runs, all steps green
- [ ] PR deploy workflow runs → Firebase posts a preview URL as a PR comment
- [ ] Merge PR to main → production deploy workflow runs → live Firebase Hosting URL serves the app
- [ ] Deployed web app connects to backend WebSocket and canvas loads correctly

---

## Key Numbers Reference

| Metric | Value |
|--------|-------|
| Canvas size | 1000 × 1000 px (1,000,000 pixels) |
| Chunk size | 250 × 250 px |
| Total chunks | 4 × 4 = 16 (no partial chunks — divides exactly) |
| Bytes per chunk (wire) | 250 KB (250 × 250 × 4 bytes) |
| Total canvas in memory | ~4 MB (all 16 chunks always cacheable) |
| Chunks in LRU cache | 16 (entire canvas fits) |
| Chunk eviction timeout | 30 s out of viewport |
| WS batch flush interval | 32 ms |
| Viewport debounce | 100 ms |
| Rate limit | 1 pixel / 5 s / user |
| Reconnect backoff max | 30 s |
| Zoom range | fit-screen → 40× |
| Minimap size | 120 × 120 px (square, matches 1:1 canvas aspect) |
| Preset colours | 16 (r/place 2022 palette) |
| Recently used colours saved | 8 |
