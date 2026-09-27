import { chromium } from '/Users/eiyuto/dev/contact-outreach/node_modules/playwright/index.mjs';
import fs from 'fs'; import http from 'http'; import path from 'path';
const root=process.cwd(); const deck=JSON.parse(fs.readFileSync('../live/project/deck.json'));
const only=process.argv[2]?process.argv[2].split(','):deck.order;
const fonts=Object.values(deck.faces).map(f=>`<link rel="stylesheet" href="${f.href}">`).join('');
const srv=http.createServer((q,r)=>{let u=decodeURIComponent(q.url.split('?')[0]);
 if(u.startsWith('/_blob/')){const f=path.join(root,'blob',u.slice(7));try{const b=fs.readFileSync(f);r.writeHead(200,{'content-type':f.endsWith('png')?'image/png':'image/gif'});r.end(b)}catch{r.writeHead(404);r.end()}return}
 const id=u.slice(1);const s=fs.readFileSync(`../live/project/slides/${id}.html`,'utf8').replace(/<aside>[\s\S]*?<\/aside>/,'');
 r.writeHead(200,{'content-type':'text/html'});r.end(`<!doctype html><meta charset=utf-8>${fonts}<style>*{margin:0;box-sizing:border-box}body{width:1920px;height:1080px;overflow:hidden;background:#888}section>*:not([style*="position:absolute"]){position:relative}section{position:relative;width:1920px;height:1080px;overflow:hidden}ul,ol{padding-left:1.2em}table{border-collapse:collapse}th,td{text-align:left;padding:10px 14px;border-bottom:1px solid rgba(0,0,0,.15);vertical-align:top}</style>${s}`)}).listen(8931);
const b=await chromium.launch(); const pg=await b.newPage({viewport:{width:1920,height:1080}});
for(const id of only){await pg.goto('http://127.0.0.1:8931/'+id);await pg.waitForTimeout(1200);
 const over=await pg.evaluate(()=>[...document.querySelectorAll('section *')].filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&(r.right>1924||r.bottom>1084)&&getComputedStyle(e).position!=='absolute'}).map(e=>e.tagName+':'+(e.textContent||'').slice(0,40)+':'+Math.round(e.getBoundingClientRect().bottom)).slice(0,5));
 const sec=await pg.evaluate(()=>{const s=document.querySelector('section');return Math.max(...[...s.children].filter(c=>getComputedStyle(c).position!=='absolute').map(c=>Math.round(c.getBoundingClientRect().bottom)))});
 console.log(id,'contentBottom',sec,over.length?JSON.stringify(over):'');
 await pg.screenshot({path:`s_${id}.png`});}
await b.close(); srv.close();
