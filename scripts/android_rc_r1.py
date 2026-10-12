"""Build and verify one private staging APK. Never reads signing credentials."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

PACKAGE = 'com.codephantom.app'
CERTIFICATE = '67b51a8fa5577620451f83c767cc3c41b72e38464ee6f47a1707e5815622b7ae'
API_URL = 'https://code-phantom-backend-staging.up.railway.app/api/v1'
VERSION_CODE = 14
VERSION_NAME = '1.0.1-rc1'
BRANCH = 'refs/heads/reconcile/enkidu-staging-r1'
ASSET = 'assets/brand/android_rc_r1_identity.json'
APK_ASSET = 'assets/flutter_assets/' + ASSET
ROOT = Path(__file__).resolve().parent.parent
PERMISSIONS = {
    'android.permission.INTERNET', 'android.permission.POST_NOTIFICATIONS',
    'android.permission.ACCESS_NETWORK_STATE', 'android.permission.WAKE_LOCK',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'com.google.android.c2dm.permission.RECEIVE',
    PACKAGE + '.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def identity(environment):
    require(environment.get('API_BASE_URL') == API_URL, 'RC requires the reviewed staging API URL.')
    require(environment.get('GITHUB_EVENT_NAME') == 'workflow_dispatch', 'RC is manual/private only.')
    require(environment.get('GITHUB_REF') == BRANCH, 'RC requires the existing reconciliation branch.')
    require(environment.get('GITHUB_REPOSITORY') == 'st10490392/code-phantom-App', 'Unexpected RC repository.')
    require(environment.get('ENKIDU_REQUESTED', 'false') == 'false', 'ENKIDU must remain disabled.')
    commit = environment.get('GITHUB_SHA', '')
    require(re.fullmatch(r'[0-9a-f]{40}', commit) is not None, 'Missing source commit identity.')
    return {
        'schema_version': 1, 'application_id': PACKAGE, 'version_code': VERSION_CODE,
        'version_name': VERSION_NAME, 'source_commit': commit,
        'app_env': 'staging', 'api_base_url': API_URL, 'push_enabled': True,
        'enkidu_shadow_view_enabled': False, 'scanner_review_actions_enabled': False,
        'execution_enabled': False, 'customer_publication_enabled': False,
    }


def build_arguments():
    return ['flutter', 'build', 'apk', '--release', '--obfuscate',
            '--split-debug-info=build/debug-info', '--build-name=' + VERSION_NAME,
            '--build-number=' + str(VERSION_CODE), '--dart-define=APP_ENV=staging',
            '--dart-define=API_BASE_URL=' + API_URL, '--dart-define=PUSH_ENABLED=true',
            '--dart-define=ENKIDU_SHADOW_VIEW_ENABLED=false',
            '--dart-define=SCANNER_REVIEW_ACTIONS=false']


def run_public_tool(arguments):
    # Tool failures do not print raw errors or environment values.
    result = subprocess.run(arguments, capture_output=True, text=True)
    require(result.returncode == 0, 'APK inspection tool failed: ' + Path(arguments[0]).name)
    return result.stdout


def parse_badging(text):
    match = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", text, re.M)
    require(match is not None, 'APK package metadata missing.')
    sdk = re.search(r"^sdkVersion:'(\d+)'", text, re.M)
    target = re.search(r"^targetSdkVersion:'(\d+)'", text, re.M)
    require(sdk is not None and target is not None, 'APK SDK metadata missing.')
    permissions = set(re.findall(r"^uses-permission(?:-sdk-\d+)?: name='([^']+)'", text, re.M))
    require(match[1] == PACKAGE, 'APK application ID mismatch.')
    require(int(match[2]) == VERSION_CODE and int(match[2]) > 13, 'APK version code mismatch.')
    require(match[3] == VERSION_NAME, 'APK version name mismatch.')
    require(int(sdk[1]) == 24 and int(target[1]) == 36, 'Unexpected SDK compatibility change.')
    require('application-debuggable' not in text, 'APK is debuggable.')
    require({'android.permission.INTERNET', 'android.permission.POST_NOTIFICATIONS'} <= permissions,
            'Required Android permissions missing.')
    require(permissions <= PERMISSIONS, 'Unexpected Android permission; explicit review required.')
    require("native-code: 'armeabi-v7a' 'arm64-v8a' 'x86_64'" in text or
            set(re.findall(r"'([^']+)'", next((line for line in text.splitlines() if line.startswith('native-code:')), ''))) ==
            {'armeabi-v7a', 'arm64-v8a', 'x86_64'}, 'APK ABI compatibility mismatch.')
    return {'application_id': match[1], 'version_code': int(match[2]), 'version_name': match[3],
            'min_sdk': int(sdk[1]), 'target_sdk': int(target[1]), 'permissions': sorted(permissions)}


def verify_certificate(text):
    certificates = re.findall(r'certificate SHA-256 digest:\s*([a-fA-F0-9]{64})', text)
    require(certificates and set(value.lower() for value in certificates) == {CERTIFICATE},
            'APK signing certificate mismatch.')
    require('CN=Android Debug' not in text, 'Debug signing is forbidden.')
    return CERTIFICATE


def verify_embedded(apk, expected):
    with zipfile.ZipFile(apk) as archive:
        require(json.loads(archive.read(APK_ASSET)) == expected, 'Embedded RC build identity mismatch.')
        require(API_URL.encode() in archive.read('lib/arm64-v8a/libapp.so'),
                'Reviewed API URL missing from compiled Android code.')


def verify():
    apk = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
    require(apk.is_file(), 'RC APK is missing.')
    sdk = Path(os.environ.get('ANDROID_HOME', os.environ.get('ANDROID_SDK_ROOT', '')))
    tools = sorted((sdk / 'build-tools').glob('*/apksigner'), key=lambda p: tuple(int(x) for x in re.findall(r'\d+', p.parent.name)))
    require(bool(tools), 'Android signing verifier unavailable.')
    signer = tools[-1]
    signature = run_public_tool([str(signer), 'verify', '--verbose', '--print-certs', str(apk)])
    certificate = verify_certificate(signature)
    badging = run_public_tool([str(signer.parent / 'aapt'), 'dump', 'badging', str(apk)])
    report = parse_badging(badging)
    expected = identity(os.environ)
    verify_embedded(apk, expected)
    resources = run_public_tool([str(signer.parent / 'aapt'), 'dump', '--values', 'resources', str(apk)])
    require('codephantom-technologies' in resources and 'google_app_id' in resources,
            'Expected native Firebase resources missing.')
    checksum = hashlib.sha256(apk.read_bytes()).hexdigest()
    report.update({'apk_sha256': checksum, 'certificate_sha256': certificate,
                   'signature_verified': True, 'firebase_resources_verified': True,
                   'build_identity': expected, 'physical_upgrade_tested': False})
    output = ROOT / 'build/android-rc-r1'
    output.mkdir(parents=True, exist_ok=True)
    filename = 'CodePhantom-1.0.1-rc1-code14.apk'
    shutil.copyfile(apk, output / filename)
    shutil.copyfile(ROOT / 'pubspec.lock', output / 'resolved-pubspec.lock')
    shutil.copytree(ROOT / 'build/debug-info', output / 'debug-symbols', dirs_exist_ok=True)
    report['resolved_dependencies_sha256'] = hashlib.sha256((output / 'resolved-pubspec.lock').read_bytes()).hexdigest()
    (output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    (output / 'SHA256SUMS.txt').write_text(checksum + '  ' + filename + '\n')
    print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['preflight', 'build', 'verify'])
    command = parser.parse_args().command
    if command in ('preflight', 'build'):
        expected = identity(os.environ)
        require(re.search(r'^version: ' + re.escape(VERSION_NAME) + r'\+' + str(VERSION_CODE) + r'$',
                          (ROOT / 'pubspec.yaml').read_text(), re.M), 'RC source version mismatch.')
        if command == 'build':
            (ROOT / ASSET).write_text(json.dumps(expected, indent=2) + '\n')
            subprocess.run(build_arguments(), cwd=ROOT, check=True)
        else:
            print('Private RC request validated; code 14, staging, V5/execution/publication disabled.')
    else:
        verify()


if __name__ == '__main__':
    try:
        main()
    except ValueError as exc:
        raise SystemExit('Android RC refused: ' + str(exc)) from None
    except (OSError, subprocess.CalledProcessError, KeyError, zipfile.BadZipFile):
        raise SystemExit('Android RC validation/build failed; no artifact approved. Inspect the failing check without exposing credentials.') from None
