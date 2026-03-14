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
