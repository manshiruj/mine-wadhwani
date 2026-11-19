#!/usr/bin/env bash
# Run the backend (Node, port 1425) and the Flutter web app (Chrome) together.
# Usage: ./start.sh        Stop: Ctrl+C (stops both)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-1425}"
WEB_PORT="${WEB_PORT:-58087}"

for cmd in node npm flutter lsof curl; do
  command -v "$cmd" >/dev/null || { echo "Missing '$cmd'. Install it first."; exit 1; }
done
[ -f "$ROOT/backend/.env" ] || { echo "backend/.env is missing (MongoDB, JWT, Cloudinary, ROBOFLOW_API_KEY, LLM_API_KEY)."; exit 1; }
if lsof -ti "tcp:$PORT" >/dev/null; then
  echo "Port $PORT is already in use. Stop that process (lsof -ti tcp:$PORT | xargs kill) or run: PORT=1426 ./start.sh"
  exit 1
fi

# ── Backend ───────────────────────────────────────────────
cd "$ROOT/backend"
[ -d node_modules ] || npm install
PORT="$PORT" node index.js &
BACKEND_PID=$!
trap 'echo; echo "Stopping backend..."; kill "$BACKEND_PID" 2>/dev/null || true' EXIT INT TERM

echo "Waiting for backend on http://localhost:$PORT ..."
for _ in $(seq 1 60); do
  curl -sf "http://localhost:$PORT/health" >/dev/null && break
  kill -0 "$BACKEND_PID" 2>/dev/null || { echo "Backend exited. Check the log above."; exit 1; }
  sleep 0.5
done
curl -sf "http://localhost:$PORT/health" >/dev/null || { echo "Backend did not start in 30 s."; exit 1; }
echo "Backend ready."

# ── Frontend ──────────────────────────────────────────────
cd "$ROOT/frontend"
flutter pub get
# Route files (*.gr.dart) are gitignored, so generate them on a fresh checkout.
[ -f lib/core/routing/app_router.gr.dart ] || dart run build_runner build --delete-conflicting-outputs

flutter run -d chrome --web-port "$WEB_PORT" --dart-define=API_BASE_URL="http://localhost:$PORT"
