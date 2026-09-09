// Stage generated Gallery SVGs for chat without changing their geometry.
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const output = path.join(import.meta.dirname, 'gallery-review-2026-09-09');
fs.mkdirSync(output, { recursive: true });
const markdown = fs.readFileSync(path.join(root, 'GALLERY.md'), 'utf8');
const figures = [...markdown.matchAll(/!\[([^\]]*)\]\((docs\/gallery\/[^)]+)\)/g)];
for (const [, title, filename] of figures) {
  let svg = fs.readFileSync(path.join(root, filename), 'utf8');
  const opening = svg.match(/<svg\b[^>]*>/)[0];
  const viewBox = opening.match(/viewBox="([^"]+)"/)[1];
  const [x, y, width, height] = viewBox.trim().split(/[ ,]+/).map(Number);
  if (![x, y, width, height].every(Number.isFinite) || width <= 0 || height <= 0)
    throw new Error(`Invalid viewBox: ${filename}`);
  if (!/<(?:path|circle|polygon|line)\b/.test(svg)) throw new Error(`No geometry: ${filename}`);
  if (/\b(?:NaN|Infinity)\b/.test(svg)) throw new Error(`Nonfinite geometry: ${filename}`);
  let sized = opening;
  if (!/\bwidth=/.test(sized)) sized = sized.replace('>', ' width="1200">');
  if (!/\bheight=/.test(sized)) sized = sized.replace('>', ` height="${1200 * height / width}">`);
  svg = svg.replace(opening, `${sized}<rect x="${x}" y="${y}" width="${width}" height="${height}" fill="white"/>`);
  fs.writeFileSync(path.join(output, path.basename(filename)), svg);
  console.log(`${title}: ${path.basename(filename)}`);
}
console.log(`Staged ${figures.length} Gallery previews.`);
const studies = figures.filter(([, , filename]) => /gallery-(intersection|difference)-/.test(filename));
for (let batch = 0; batch < studies.length; batch += 4) {
  let sheet = '<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1320" viewBox="0 0 1400 1320"><rect x="0" y="0" width="1400" height="1320" fill="white"/>';
  studies.slice(batch, batch + 4).forEach(([, title, filename], row) => {
    let svg = fs.readFileSync(path.join(output, path.basename(filename)), 'utf8');
    svg = svg.slice(svg.indexOf('<svg'));
    const opening = svg.match(/<svg\b[^>]*>/)[0];
    const replaced = opening.replace(/\s(?:width|height|x|y)="[^"]*"/g, '').replace('>', ` x="10" y="${row * 330 + 35}" width="1380" height="285">`);
    sheet += `<text x="20" y="${row * 330 + 25}" font-family="sans-serif" font-size="20">${title}</text>` + svg.replace(opening, replaced);
  });
  fs.writeFileSync(path.join(output, `boolean-studies-${batch / 4 + 1}.svg`), sheet + '</svg>');
}
