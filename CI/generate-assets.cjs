// Reproducible, original geometric artwork. No network, packages or copyrighted album art.
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const root = path.resolve(__dirname, '..', 'Assets', 'Assets.xcassets');
function crc32(data) {
  let crc = 0xffffffff;
  for (const value of data) {
    crc ^= value;
    for (let j = 0; j < 8; j++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const name = Buffer.from(type), size = Buffer.alloc(4), crc = Buffer.alloc(4);
  size.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(Buffer.concat([name, data])));
  return Buffer.concat([size, name, data, crc]);
}
function png(size, pixel) {
  const raw = Buffer.alloc((size * 3 + 1) * size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const rgb = pixel(x / size, y / size);
      for (let c = 0; c < 3; c++) raw[y * (size * 3 + 1) + 1 + x * 3 + c] = Math.max(0, Math.min(255, Math.round(rgb[c])));
    }
  }
  const header = Buffer.alloc(13); header.writeUInt32BE(size); header.writeUInt32BE(size, 4); header[8] = 8; header[9] = 2;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}
function artwork(style) {
  return (x, y) => {
    const glow = Math.exp(-((x - .64) ** 2 + (y - .36) ** 2) * 10);
    if (style === 0) {
      let color = [12 + 100 * glow, 19 + 28 * glow, 43 + 105 * glow];
      if (Math.hypot(x - .64, y - .34) < .17) color = [232, 130 + 60 * y, 148];
      if (y > .61 + .07 * Math.sin(x * 9)) color = [18, 28, 56];
      if (y > .62 && Math.abs(x - .48) < (y - .6) * .58) color = [9, 15, 27];
      if (y > .68 && Math.abs(x - .48) < .004 && Math.floor(y * 35) % 3) color = [226, 196, 166];
      return color;
    }
    if (style === 1) {
      let color = [205 + 35 * (1-y), 108 + 45 * (1-y), 91 + 22 * y];
      if (Math.hypot(x - .5, y - .42) < .24) color = [255, 222, 152];
      if (y > .66 + .055 * Math.sin(x * 7)) color = [98, 81 + y * 25, 112 + y * 28];
      if (y > .8 + .05 * Math.cos(x * 10)) color = [47, 67, 94];
      return color;
    }
    let color = [17 + 40 * glow, 55 + 65 * glow, 67 + 70 * glow];
    for (let i = 0; i < 6; i++) {
      if (y > .45 + i * .12 + .09 * Math.sin(x * 6 + i)) color = [17 + i * 3, 50 + i * 10, 65 + i * 11];
    }
    if (Math.hypot(x-.7, y-.26) < .09) color = [212, 232, 216];
    if (Math.floor(x * 37 + y * 7) % 13 === 0 && y < .5) color = color.map(c => c + 12);
    return color;
  };
}
fs.mkdirSync(root, {recursive: true});
fs.writeFileSync(path.join(root, 'Contents.json'), JSON.stringify({info: {author:'xcode', version:1}}, null, 2));
for (const [i, name] of ['demo-midnight', 'demo-golden', 'demo-rain'].entries()) {
  const dir = path.join(root, name + '.imageset'); fs.mkdirSync(dir, {recursive:true});
  fs.writeFileSync(path.join(dir, name + '.png'), png(480, artwork(i)));
  fs.writeFileSync(path.join(dir, 'Contents.json'), JSON.stringify({images:[{filename:name+'.png', idiom:'universal'}], info:{author:'xcode',version:1}}, null, 2));
}
const icon = path.join(root, 'AppIcon.appiconset'); fs.mkdirSync(icon, {recursive:true});
fs.writeFileSync(path.join(icon, 'AppIcon.png'), png(1024, (x,y) => {
  let c = [10+12*(1-y), 19+25*(1-y), 25+18*(1-y)];
  const ring = Math.hypot(x-.5,y-.5);
  if (ring > .29 && ring < .31) c = [129, 155, 255];
  if (x > .45 && x < .50 && y > .31 && y < .62) c = [238,248,244];
  if (x > .49 && x < .67 && y > .31 && y < .37) c = [238,248,244];
  if (((x-.415)/.085)**2 + ((y-.63)/.065)**2 < 1) c = [129,155,255];
  return c;
}));
fs.writeFileSync(path.join(icon, 'Contents.json'), JSON.stringify({images:[{filename:'AppIcon.png',idiom:'universal',platform:'ios',size:'1024x1024'}],info:{author:'xcode',version:1}},null,2));
console.log('Generated 3 offline covers and AppIcon.');
