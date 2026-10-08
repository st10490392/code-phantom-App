"""Validate/install client config without logging contents. No server keys."""
import argparse
import base64
import json
import os
from pathlib import Path


def validate(raw):
    try:
        data = json.loads(raw)
        info = data['project_info']
        if info['project_id'] != 'codephantom-technologies' or not str(info['project_number']).isdigit():
            raise ValueError()
        clients = [c for c in data['client'] if c['client_info'].get('android_client_info', {}).get('package_name') == 'com.codephantom.app']
        if len(clients) != 1:
            raise ValueError()
        client = clients[0]
        app_id = client['client_info']['mobilesdk_app_id']
        if not app_id.startswith('1:' + str(info['project_number']) + ':android:') or not client['api_key'][0]['current_key']:
            raise ValueError()
        if any(k in data for k in ('private_key', 'client_email')):
            raise ValueError()
    except (ValueError, TypeError, KeyError, IndexError, AttributeError):
        raise ValueError('Invalid Firebase Android configuration: expected codephantom-technologies / com.codephantom.app.') from None
    return data


def install(encoded, destination):
    if not encoded:
        raise ValueError('Missing staging secret FIREBASE_GOOGLE_SERVICES_JSON_BASE64.')
    try:
        raw = base64.b64decode(encoded, validate=True)
    except (ValueError, base64.binascii.Error):
        raise ValueError('FIREBASE_GOOGLE_SERVICES_JSON_BASE64 must be valid base64.') from None
    validate(raw)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(raw)
    destination.chmod(0o600)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--validate-file', type=Path)
    args = parser.parse_args()
    try:
        if args.validate_file:
            validate(args.validate_file.read_bytes())
        else:
            install(os.environ.get('FIREBASE_GOOGLE_SERVICES_JSON_BASE64'), Path('android/app/google-services.json'))
    except (ValueError, OSError) as exc:
        # OSError filenames aren't credentials; JSON parse errors never printed.
        raise SystemExit(str(exc)) from None
    print('Firebase Android project/package configuration validated.')
