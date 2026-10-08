#!/usr/bin/env bash
set -euo pipefail
# Builds only; never deploys or sends broker commands.
app_api_url="${API_BASE_URL:?Set the verified staging API_BASE_URL ending in /api/v1}"
app_origin="${app_api_url%/api/v1}"
if [ "$app_origin" = "$app_api_url" ] || [[ "$app_api_url" != https://* ]]; then
  echo 'Staging API_BASE_URL must be HTTPS and end in /api/v1.' >&2
  exit 1
fi
mkdir -p build/demo-evidence
curl --fail --silent --show-error "$app_origin/health" -o build/demo-evidence/health.json
python3 - <<'PY'
import json
from pathlib import Path
health=json.loads(Path('build/demo-evidence/health.json').read_text())
if health.get('env') != 'staging' or health.get('status') != 'ok':
    raise SystemExit('Backend environment mismatch: staging build refused.')
PY
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=APP_ENV=staging --dart-define="API_BASE_URL=$app_api_url"
flutter build web --release --no-web-resources-cdn --dart-define=APP_ENV=staging --dart-define="API_BASE_URL=$app_api_url"
python3 - "$app_api_url" <<'PY'
import hashlib,json,subprocess,sys
from pathlib import Path
apk=Path('build/app/outputs/flutter-apk/app-debug.apk')
manifest={'source_sha':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'app_env':'staging','api_base_url':sys.argv[1],'execution_enabled':False,'apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'flutter':subprocess.check_output(['flutter','--version'],text=True)}
Path('build/demo-evidence/build.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
