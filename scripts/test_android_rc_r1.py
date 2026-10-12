import copy
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import android_rc_r1 as rc
from retain_private_rc_r1 import assert_private_draft


class AndroidReleaseCandidateTests(unittest.TestCase):
    def setUp(self):
        self.env = {'API_BASE_URL': rc.API_URL, 'GITHUB_EVENT_NAME': 'workflow_dispatch',
                    'GITHUB_REF': rc.BRANCH, 'GITHUB_REPOSITORY': 'st10490392/code-phantom-App',
                    'GITHUB_SHA': 'a' * 40, 'ENKIDU_REQUESTED': 'false'}
        self.badging = "\n".join([
            "package: name='com.codephantom.app' versionCode='16' versionName='1.0.1-rc3'",
            "sdkVersion:'24'", "targetSdkVersion:'36'",
            "uses-permission: name='android.permission.INTERNET'",
            "uses-permission: name='android.permission.POST_NOTIFICATIONS'",
            "native-code: 'armeabi-v7a' 'arm64-v8a' 'x86_64'",
        ])

    def test_wrong_destination_or_execution_request_is_rejected(self):
        for key, value in [('API_BASE_URL', 'https://other.example/api/v1'),
                           ('GITHUB_EVENT_NAME', 'push'), ('GITHUB_REF', 'refs/heads/main'),
                           ('GITHUB_REPOSITORY', 'other/repo'), ('ENKIDU_REQUESTED', 'true')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                rc.identity(dict(self.env, **{key: value}))

    def test_pinned_arguments_and_identity_disable_execution(self):
        identity = rc.identity(self.env)
        self.assertFalse(identity['enkidu_shadow_view_enabled'])
        self.assertFalse(identity['scanner_review_actions_enabled'])
        self.assertFalse(identity['execution_enabled'])
        self.assertFalse(identity['customer_publication_enabled'])
        args = rc.build_arguments()
        self.assertIn('--build-number=16', args)
        self.assertIn('--dart-define=API_BASE_URL=' + rc.API_URL, args)
        self.assertIn('--dart-define=ENKIDU_SHADOW_VIEW_ENABLED=false', args)
        self.assertIn('--dart-define=SCANNER_REVIEW_ACTIONS=false', args)

    def test_actual_manifest_rejects_wrong_identity_version_sdk_and_permissions(self):
        self.assertEqual(rc.parse_badging(self.badging)['version_code'], 16)
        for invalid in [self.badging.replace('com.codephantom.app', 'other.app'),
                        self.badging.replace("versionCode='16'", "versionCode='14'"),
                        self.badging.replace("sdkVersion:'24'", "sdkVersion:'26'"),
                        self.badging + "\nuses-permission: name='android.permission.READ_CONTACTS'",
                        self.badging + '\napplication-debuggable',
                        self.badging.replace('android.permission.POST_NOTIFICATIONS', 'other.permission'),
                        self.badging.replace(" 'x86_64'", '')]:
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                rc.parse_badging(invalid)

    def test_certificate_must_exactly_match_existing_release(self):
        self.assertEqual(rc.verify_certificate('V2 Signer: certificate SHA-256 digest: ' + rc.CERTIFICATE), rc.CERTIFICATE)
        for invalid in ['', 'certificate SHA-256 digest: ' + '0' * 64,
                        'CN=Android Debug\ncertificate SHA-256 digest: ' + rc.CERTIFICATE]:
            with self.assertRaises(ValueError):
                rc.verify_certificate(invalid)

    def test_embedded_identity_and_compiled_destination_must_match(self):
        expected = rc.identity(self.env)
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / 'fixture.zip'
            def write(identity, binary):
                with zipfile.ZipFile(apk, 'w') as archive:
                    archive.writestr(rc.APK_ASSET, json.dumps(identity))
                    archive.writestr('lib/arm64-v8a/libapp.so', binary)
            write(expected, rc.API_URL)
            rc.verify_embedded(apk, expected)
            altered = copy.deepcopy(expected)
            altered['enkidu_shadow_view_enabled'] = True
            write(altered, rc.API_URL)
            with self.assertRaises(ValueError):
                rc.verify_embedded(apk, expected)

            write(expected, 'https://other.example')
            with self.assertRaises(ValueError):
                rc.verify_embedded(apk, expected)

    def test_retention_refuses_public_repository_or_published_release(self):
        repository = {'full_name': 'st10490392/code-phantom-App', 'private': True}
        draft = {'draft': True, 'published_at': None}
        assert_private_draft(repository, draft)
        for repo, release in [(dict(repository, private=False), draft),
                              (repository, dict(draft, draft=False)),
                              (repository, dict(draft, published_at='2026-10-12T00:00:00Z'))]:
            with self.assertRaises(ValueError):
                assert_private_draft(repo, release)


if __name__ == '__main__':
    unittest.main()
