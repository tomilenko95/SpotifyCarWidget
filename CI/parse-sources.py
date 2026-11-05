"""Optional syntax/config checks, NOT Swift type checking or an Xcode build.

python -m pip install --target build/validation --only-binary=:all: -r CI/validation-requirements.txt
python CI/parse-sources.py
"""
import json
import pathlib
import plistlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'build' / 'validation'))
import yaml
from tree_sitter import Language, Parser
import tree_sitter_swift

parser = Parser(Language(tree_sitter_swift.language()))
errors = []
sources = [p for p in root.rglob('*.swift') if 'build' not in p.relative_to(root).parts]
for file in sources:
    tree = parser.parse(file.read_bytes())
    pending = [tree.root_node]
    while pending:
        node = pending.pop()
        if node.is_error or node.is_missing:
            errors.append(f'{file.relative_to(root)}:{node.start_point.row + 1}: {node.type}: {node.text[:100]!r}')
        pending.extend(reversed(node.children))
for file in [root / 'project.yml', root / 'codemagic.yaml', root / '.github/workflows/ios.yml']:
    with file.open(encoding='utf-8') as stream:
        yaml.safe_load(stream)
spec = yaml.safe_load((root / 'project.yml').read_text())
for target, definition in spec['targets'].items():
    for source in definition['sources']:
        source = source['path'] if isinstance(source, dict) else source
        assert (root / source).exists(), f'{target}: missing source {source}'
for configuration in spec['configFiles'].values():
    assert (root / configuration).is_file(), configuration
for file in (root / 'Config').iterdir():
    if file.suffix in ('.plist', '.entitlements'):
        plistlib.loads(file.read_bytes())
json.loads((root / 'Documentation/OAuthHosting/.well-known/apple-app-site-association').read_text())
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print(f'Swift grammar parsed: {len(sources)} files; YAML/plist/AASA parsed. No type checking or SDK validation.')
