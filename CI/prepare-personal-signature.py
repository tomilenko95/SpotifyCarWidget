"""Carry explicit shared-keychain entitlements into Sideloadly's re-signing step.

The local ad-hoc signature is NOT an Apple Ad Hoc distribution signature and
does NOT make the IPA installable. Sideloadly must sign it with the user's profile.
No certificate or private signing key is sent to CI.
"""
import os
import pathlib
import plistlib
import re
import subprocess
import sys

team = os.environ.get('KEYCHAIN_TEAM_ID', '')
if not re.fullmatch(r'[A-Z0-9]{10}', team):
    raise SystemExit('KEYCHAIN_TEAM_ID must be the 10-character prefix of the selected Apple signing profile.')
app = pathlib.Path(sys.argv[1]).resolve()
extensions = sorted((app / 'PlugIns').glob('*.appex'))
if len(extensions) != 1:
    raise SystemExit('Expected exactly one Widget Extension.')
for index, bundle in enumerate([*extensions, app]):
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    entitlements = {
        'application-identifier': team + '.' + info['CFBundleIdentifier'],
        'com.apple.developer.team-identifier': team,
        'keychain-access-groups': [team + '.com.carwidget.shared'],
        'get-task-allow': True,
    }
    path = pathlib.Path('build') / f'personal-signature-{index}.plist'
    path.write_bytes(plistlib.dumps(entitlements))
    subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements', str(path),
                    '--generate-entitlement-der', str(bundle)], check=True)
    subprocess.run(['codesign', '--verify', '--strict', str(bundle)], check=True)
print('Shared Keychain entitlements embedded. This IPA still requires real device re-signing.')
