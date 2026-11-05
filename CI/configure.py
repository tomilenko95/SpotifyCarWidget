"""Only public identifiers go into xcconfig; signing material stays in CI's keychain."""
import os
import pathlib
import re

keys = ['APP_BUNDLE_ID', 'APP_GROUP', 'OAUTH_HOST', 'SPOTIFY_CLIENT_ID', 'DEVELOPMENT_TEAM']
lines = []
for key in keys:
    value = os.environ[key]
    if not re.fullmatch(r'[A-Za-z0-9.-]+', value):
        raise SystemExit(f'Invalid configuration value: {key}')
    lines.append(f'{key} = {value}')
pathlib.Path('Config/Local.xcconfig').write_text('\n'.join(lines) + '\n', encoding='utf-8')
