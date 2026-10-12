"""Quota fallback: an UNPUBLISHED draft in the existing PRIVATE repository.

Never publishes a release, changes visibility, creates Git refs, deletes evidence,
or accesses signing credentials. Uses the existing workflow's Contents token.
"""
import hashlib
import json
import os
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request
import zipfile

import android_rc_r1 as rc


def assert_private_draft(repository, release):
    rc.require(repository.get('full_name') == 'st10490392/code-phantom-App' and repository.get('private') is True,
               'Fallback requires the existing private App repository.')
    rc.require(release.get('draft') is True and release.get('published_at') is None,
               'Fallback must remain an unpublished draft.')


def main():
    rc.require(os.environ.get('GITHUB_EVENT_NAME') == 'workflow_dispatch' and os.environ.get('GITHUB_REF') == rc.BRANCH,
               'Private retention requires the authorized manual RC branch.')
    token = os.environ.get('GH_TOKEN')
    rc.require(bool(token), 'Workflow Contents authentication unavailable.')
    base = 'https://api.github.com/repos/st10490392/code-phantom-App'
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *unused):
            return None
    opener = urllib.request.build_opener(NoRedirect)
    def request(url, data=None, content_type='application/json'):
        parsed = urllib.parse.urlparse(url)
        rc.require(parsed.scheme == 'https' and parsed.hostname in ('api.github.com', 'uploads.github.com'),
                   'Unexpected authenticated retention endpoint.')
        req = urllib.request.Request(url, data=data, headers={
            'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2026-03-10', 'Content-Type': content_type})
        with opener.open(req, timeout=120) as response:
            return json.loads(response.read())
    repository = request(base)
    # Check privacy before creating anything. No publication request exists here.
    assert_private_draft(repository, {'draft': True, 'published_at': None})
    folder = rc.ROOT / 'build/android-rc-r1'
    verification = json.loads((folder / 'verification.json').read_text())
    apk = folder / 'CodePhantom-1.0.1-rc1-code14.apk'
    rc.require(hashlib.sha256(apk.read_bytes()).hexdigest() == verification['apk_sha256'], 'Retention APK hash mismatch.')
    rc.require(verification['signature_verified'] and verification['certificate_sha256'] == rc.CERTIFICATE,
               'Only the verified original-signer APK may be retained.')
    rc.require(verification['build_identity']['source_commit'] == os.environ.get('GITHUB_SHA'), 'Retention source mismatch.')
    release = request(base + '/releases', json.dumps({
        'tag_name': 'private-android-rc-r1-' + os.environ['GITHUB_RUN_ID'],
        'target_commitish': os.environ['GITHUB_SHA'], 'name': 'PRIVATE Android RC R1 — code 14',
        'body': 'Unpublished private owner candidate. No deployment or ENKIDU activation.\nSource: ' + os.environ['GITHUB_SHA'] +
                '\nAPK SHA-256: ' + verification['apk_sha256'],
        'draft': True, 'prerelease': True, 'generate_release_notes': False,
    }).encode())
    assert_private_draft(repository, release)
    symbols = folder / 'debug-symbols.zip'
    with zipfile.ZipFile(symbols, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted((folder / 'debug-symbols').glob('*.symbols')):
            archive.write(path, path.name)
    files = [apk, folder / 'verification.json', folder / 'SHA256SUMS.txt', folder / 'resolved-pubspec.lock', symbols]
    upload = release['upload_url'].split('{', 1)[0]
    assets = []
    for path in files:
        asset = request(upload + '?name=' + urllib.parse.quote(path.name), path.read_bytes(), 'application/octet-stream')
        assets.append({'name': path.name, 'id': asset['id'], 'bytes': asset['size'],
                       'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    final = request(base + '/releases/' + str(release['id']))
    assert_private_draft(request(base), final)
    result = {'private_repository': True, 'draft': True, 'published': False,
              'release_id': release['id'], 'url': final['html_url'], 'assets': assets}
    (rc.ROOT / 'build/private-retrieval.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as exc:
        raise SystemExit('Private draft retention failed; HTTP ' + str(exc.code) + '. No credentials logged.') from None
    except ValueError as exc:
        raise SystemExit('Private draft retention refused: ' + str(exc)) from None
    except Exception:
        raise SystemExit('Private draft retention failed; no credentials logged and nothing published.') from None
