import base64
import json
import tempfile
import unittest
from pathlib import Path
from firebase_android_config import install, validate
from firebase_web_config import generate


class FirebaseConfigTest(unittest.TestCase):
    def test_web_config_is_separate_and_requires_public_vapid(self):
        config = {'PUSH_FIREBASE_PROJECT_ID': 'codephantom-technologies', 'PUSH_FIREBASE_APP_ID': '1:123:web:abc', 'PUSH_FIREBASE_API_KEY': 'public', 'PUSH_FIREBASE_SENDER_ID': '123', 'PUSH_WEB_VAPID_KEY': 'public-vapid'}
        result = generate(config, 'initialize(__FIREBASE_WEB_CONFIG__);')
        self.assertIn('1:123:web:abc', result)
        for change in ({'PUSH_WEB_VAPID_KEY': ''}, {'PUSH_FIREBASE_APP_ID': '1:123:android:abc'}):
            with self.assertRaises(ValueError): generate({**config, **change}, '__FIREBASE_WEB_CONFIG__')
    def config(self):
        return {'project_info': {'project_id': 'codephantom-technologies', 'project_number': '123'}, 'client': [{'client_info': {'mobilesdk_app_id': '1:123:android:abc', 'android_client_info': {'package_name': 'com.codephantom.app'}}, 'api_key': [{'current_key': 'public-client-key'}]}]}

    def test_valid_config_is_installed(self):
        raw = json.dumps(self.config()).encode()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'google-services.json'
            install(base64.b64encode(raw).decode(), path)
            self.assertEqual(path.read_bytes(), raw)

    def test_invalid_never_writes_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'google-services.json'
            for encoded in (None, '', 'not-base64', base64.b64encode(b'{private invalid contents').decode()):
                with self.assertRaises(ValueError): install(encoded, path)
                self.assertFalse(path.exists())

    def test_wrong_project_package_sender_or_server_key(self):
        for field in ('project', 'package', 'sender', 'private'):
            data = self.config()
            if field == 'project': data['project_info']['project_id'] = 'production-other'
            if field == 'package': data['client'][0]['client_info']['android_client_info']['package_name'] = 'other.app'
            if field == 'sender': data['client'][0]['client_info']['mobilesdk_app_id'] = '1:999:android:abc'
            if field == 'private': data['private_key'] = 'never-print-this'
            with self.assertRaises(ValueError) as error: validate(json.dumps(data))
            self.assertNotIn('never-print-this', str(error.exception))


if __name__ == '__main__': unittest.main()
