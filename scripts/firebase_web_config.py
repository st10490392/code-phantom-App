"""Generate a worker containing PUBLIC web app config, not Android config."""
import json
import os
from pathlib import Path


def generate(source, template):
    names = {'projectId': 'PUSH_FIREBASE_PROJECT_ID', 'appId': 'PUSH_FIREBASE_APP_ID', 'apiKey': 'PUSH_FIREBASE_API_KEY', 'messagingSenderId': 'PUSH_FIREBASE_SENDER_ID'}
    config = {key: source.get(value, '') for key, value in names.items()}
    if not all(config.values()) or config['projectId'] != 'codephantom-technologies' or not config['appId'].startswith('1:' + config['messagingSenderId'] + ':web:') or not source.get('PUSH_WEB_VAPID_KEY'):
        raise ValueError('Missing/invalid Firebase WEB public configuration or public VAPID key.')
    return template.replace('__FIREBASE_WEB_CONFIG__', json.dumps(config))


if __name__ == '__main__':
    try:
        result = generate(os.environ, Path('scripts/firebase-messaging-sw.template.js').read_text())
    except ValueError as exc:
        raise SystemExit(str(exc)) from None
    Path('web/firebase-messaging-sw.js').write_text(result)
    print('Firebase Web worker generated from public configuration.')
