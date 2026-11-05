const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
function files(dir) { return fs.readdirSync(dir, {withFileTypes:true}).flatMap(e => e.name.startsWith('.') || ['build','DerivedData','node_modules'].includes(e.name) ? [] : e.isDirectory() ? files(path.join(dir,e.name)) : [path.join(dir,e.name)]); }
const all = files(root);
for (const name of ['project.yml','codemagic.yaml','README.md','Config/App-Info.plist','Config/Widget-Info.plist']) assert(fs.existsSync(path.join(root,name)), name);
for (const file of all.filter(f=>f.endsWith('.json'))) JSON.parse(fs.readFileSync(file,'utf8'));
for (const name of ['Compact','Controls','CoverFocus']) {
  const source = fs.readFileSync(path.join(root,`Widgets/${name}Widget/${name}Widget.swift`),'utf8');
  assert(source.includes('.systemSmall'), `${name}: small family`);
  assert(source.includes('.containerBackground(for: .widget)'), `${name}: container background`);
}
for (const file of all.filter(f=>f.endsWith('.swift'))) {
  const source = fs.readFileSync(file,'utf8');
  assert(!/TODO|fatalError\(|client_secret/.test(source), `${file}: unfinished or secret-based code`);
  assert(!/UserDefaults[^\n]*(accessToken|refreshToken)/.test(source), `${file}: token storage`);
}
for (const name of ['demo-midnight','demo-golden','demo-rain']) {
  const png = fs.readFileSync(path.join(root,`Assets/Assets.xcassets/${name}.imageset/${name}.png`));
  assert.equal(png.readUInt32BE(16),480); assert.equal(png.readUInt32BE(20),480);
}
console.log(`Static checks passed (${all.length} files). This is NOT a Swift/Xcode build.`);
