#!/usr/bin/env node
// Dependency-free static smoke checks; run from any directory.
import {readFileSync, existsSync, statSync} from 'node:fs';
import {dirname, resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const root = dirname(fileURLToPath(import.meta.url));
const errors = [];
const assets = new Set();
const check = (condition, message) => { if (!condition) errors.push(message); };
const attr = (tag, name) => tag.match(new RegExp(`(?:^|\\s)${name}="([^"]*)"`))?.[1];
for (const name of ['index.html', 'ja/index.html', 'en/index.html']) {
  const path = join(root, name);
  const html = readFileSync(path, 'utf8');
  const tags = [...html.matchAll(/<[a-z][^>]*>/gi)].map(match => match[0]);
  const ids = tags.map(tag => attr(tag, 'id')).filter(Boolean);
  check(new Set(ids).size === ids.length, `${name}: duplicate element IDs`);
  for (const tag of tags) {
    for (const field of ['src', 'poster', 'href', 'data-src']) {
      const value = attr(tag, field);
      if (!value || /^(?:https?:|data:|mailto:)/i.test(value)) continue;
      if (value.startsWith('#')) {
        check(ids.includes(value.slice(1)), `${name}: missing anchor ${value}`);
        continue;
      }
      let target = resolve(dirname(path), value.split(/[?#]/)[0]);
      if (existsSync(target) && statSync(target).isDirectory()) target = join(target, 'index.html');
      check(target.startsWith(root + '/'), `${name}: reference escapes the site: ${value}`);
      check(existsSync(target), `${name}: missing ${field} ${value}`);
      if (existsSync(target)) assets.add(target);
    }
    if (tag.startsWith('<img ')) check(attr(tag, 'alt') !== undefined, `${name}: image has no alt attribute`);
    if (attr(tag, 'target') === '_blank') check(attr(tag, 'rel')?.split(' ').includes('noopener'), `${name}: new-tab link lacks noopener`);
    for (const field of ['aria-labelledby', 'aria-controls']) {
      const value = attr(tag, field);
      if (value) for (const id of value.split(' ')) check(ids.includes(id), `${name}: ${field} refers to missing ${id}`);
    }
  }
  if (name !== 'en/index.html') {
    const language = name.startsWith('ja/') ? 'ja' : 'en';
    check(html.includes(`<html lang="${language}">`), `${name}: wrong document language`);
    check(tags.filter(tag => tag.startsWith('<h1')).length === 1, `${name}: expected one primary heading`);
    const characters = tags.filter(tag => attr(tag, 'data-character-group'));
    check(characters.length === 30, `${name}: all 30 original companions must remain available`);
    const groups = tags.map(tag => attr(tag, 'data-group')).filter(Boolean);
    for (const card of characters) check(groups.includes(attr(card, 'data-character-group')), `${name}: companion has no group filter`);
    check(/<video[^>]*data-inline-trailer[^>]*controls/.test(html), `${name}: native video controls are required for no-JS fallback`);
    check(!/\bautoplay\b/.test(html), `${name}: background playback must respect reduced motion`);
    check(!html.includes('obake-breakroom-'), `${name}: obsolete prototype destination`);
    check(!/paw-time-play\.vercel\.app\/\?/.test(html), `${name}: unsupported game URL parameters`);
    console.log(`CHECK ${name}: anchors, assets, language, accessibility references, 30 companions`);
  } else {
    check(/http-equiv="refresh" content="0; url=\.\.\/"/.test(html), `${name}: English alias redirect`);
    console.log(`CHECK ${name}: English alias`);
  }
}
const syntax = spawnSync(process.execPath, ['--check', join(root, 'site.js')], {encoding:'utf8'});
check(syntax.status === 0, `site.js: ${syntax.stderr}`);
for (const language of ['en', 'ja']) {
  const file = join(root, `video/paw_time_${language}.mp4`);
  if (!existsSync(file)) { errors.push(`Missing ${language} trailer`); continue; }
  const data = readFileSync(file);
  check(data.subarray(4, 8).toString() === 'ftyp', `${language}: invalid MP4 header`);
  check(data.length > 1000, `${language}: empty trailer`);
}
check(readFileSync(join(root, 'site.css'), 'utf8').includes('prefers-reduced-motion:reduce'), 'Reduced-motion styles missing');
if (errors.length) {
  console.error(`FAIL: ${errors.length} issue(s)\n${errors.join('\n')}`);
  process.exitCode = 1;
} else {
  console.log(`PASS: 3 routes, script syntax, ${assets.size} local files, both trailers and reduced-motion styles`);
}
