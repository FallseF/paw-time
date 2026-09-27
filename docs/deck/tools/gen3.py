exec(open('../../gen3_base.py').read())
import json
S={}
def src(t): return f'<p style="font-family:{MONO}; font-size:24px; color:{MUT}">{t}</p>'
# 01 cover
S['cover']=(f'<section id="cover" data-transition="fade" style="background:#0A0B0E; color:#FFFFFF; font-family:{SANS}; padding:128px 128px 160px; display:grid; grid-template-columns:1fr 400px; gap:96px; align-items:center">\n'
 f'<img src="{BG}" alt="" style="position:absolute; left:0px; top:0px; width:1920px; height:1080px; object-fit:cover">'
 f'<p style="position:absolute; left:72px; bottom:24px; width:700px; font-family:{MONO}; font-size:24px; letter-spacing:1px; color:{ACC2}">TEAM DRY GRAPE · SEPTEMBER 2026</p>' + lockup() + '\n'
 f'<div style="display:flex; flex-direction:column; gap:36px"><div style="display:flex; gap:28px; align-items:baseline"><p style="font-family:{SANS}; font-size:104px; font-weight:800; color:{ACC}">01</p><h1 style="font-family:{SANS}; font-size:144px; font-weight:800; line-height:1; letter-spacing:1px; color:#FFFFFF">PAW TIME</h1></div>'
 f'<p style="font-size:64px; font-weight:700; line-height:1.15; color:#FFFFFF">Let\'s work together.</p>'
 f'<p style="font-size:40px; line-height:1.3; color:#D3D8EA">A cat game for spot workers that shows who fits, before and after every shift.</p></div>\n'
 + phone('title',380,676,'Paw Time title screen (gameplay)') +
 '\n<aside>Paw Time. Let\'s work together. Four and a half million people do spot work in Japan. Job apps see the moment they apply, then lose sight of whether the job fit. Paw Time is a cat game they open every day, so for the first time we can see who fits and who comes back.</aside>\n</section>\n')
# 02 problem
def seg(t,sub,on):
    bg=ACCD if on else '#C9CCD3'; c='#FFFFFF' if on else '#6B7080'
    return f'<div style="flex:{2 if on else 1}; display:flex; flex-direction:column; gap:6px; justify-content:center; background:{bg}; padding:22px 28px; border-radius:6px"><p style="font-family:{MONO}; font-size:30px; font-weight:700; color:{c}">{t}</p><p style="font-size:28px; color:{c}">{sub}</p></div>'
def big(l,n,cap,s_):
    return (f'<div style="flex:1; display:flex; flex-direction:column; gap:10px; background:{INK}; padding:28px 30px; border-radius:6px">'
            f'<p style="font-family:{MONO}; font-size:24px; font-weight:700; color:{ACC}">{l}</p>'
            f'<p style="font-family:{SANS}; font-size:104px; font-weight:800; line-height:1; color:#FFFFFF">{n}</p>'
            f'<p style="font-size:32px; line-height:1.25; color:#E4E7EF">{cap}</p>'
            + (f'<p style="font-family:{MONO}; font-size:24px; color:{ACC2}">{s_}</p>' if s_ else '') + '</div>')
def chain(i,t,on=False):
    bg=ACCD if on else INK
    return f'<div style="flex:1; display:flex; gap:18px; align-items:center; background:{bg}; padding:24px 28px; border-radius:6px"><p style="font-family:{SANS}; font-size:56px; font-weight:800; line-height:1; color:{ACC if not on else "#FFFFFF"}">{i}</p><p style="font-size:34px; font-weight:700; line-height:1.2; color:#FFFFFF">{t}</p></div>'
car=f'<p style="font-family:{SANS}; font-size:56px; font-weight:800; color:{ACCD}; align-self:center">→</p>'
S['problem']=sec('problem','02','PROBLEM &amp; URGENCY','AI floods applications. None of them say who fits.',
 f'<div style="display:flex; gap:10px; align-items:stretch">' + chain('1','AI applies for everyone') + car + chain('2','Only outcome data shows fit') + car + chain('3','No tool collects it',True) + '</div>'
 + f'<div style="display:flex; gap:20px">'
 + big('WHAT','+412%','applications per recruiter','Greenhouse data, Fortune, Jul 2026')
 + big('WHY IT MATTERS NOW','$20','buys AI mass-applying','Fortune, Jul 2026')
 + big('WHO','4.52M','spot workers in Japan, the most frequent hires','Persol RI, 2025')
 + big('WHY OPTIONS FALL SHORT','1 of 4','moments job apps can see','')
 + '</div>',
 'PLACEHOLDER', 36)
# 03 insight
days=['M','T','W','T','F','S','S']
def week(label,on,col):
    cells=''.join(f'<div style="width:104px; height:104px; border-radius:14px; background:{col if i in on else "#FFFFFF"}; border:3px solid {col if i in on else LINE}; display:flex; align-items:center; justify-content:center"><p style="font-family:{MONO}; font-size:30px; font-weight:700; color:{"#FFFFFF" if i in on else "#A0A4AE"}">{d}</p></div>' for i,d in enumerate(days))
    return f'<div style="display:flex; gap:24px; align-items:center"><p style="width:230px; font-size:36px; font-weight:800; color:{INK}">{label}</p><div style="display:flex; gap:12px">{cells}</div></div>'
S['insight']=sec('insight','03','INSPIRATION / KEY INSIGHT','Job apps are only opened when people look for work.',
 f'<div style="display:grid; grid-template-columns:1fr 330px; gap:64px; align-items:center"><div style="display:flex; flex-direction:column; gap:26px">'
 f'<p style="font-family:{MONO}; font-size:26px; font-weight:700; color:{ACCD}">WHAT WE OBSERVED · A TYPICAL WEEK <span style="color:{MUT}">[ILLUSTRATIVE]</span></p>'
 + week('Job app',[4],'#8A8F9C') + week('Paw Time',[0,1,2,3,4,5,6],ACCD)
 + f'<div style="display:flex; flex-direction:column; gap:14px; border-top:2px solid {LINE}; padding:22px 0 0 0">'
 f'<p style="font-size:38px; line-height:1.25; color:{INK}"><span style="font-family:{MONO}; font-size:26px; font-weight:700; color:{ACCD}">REVEALED </span>So outcome data is never collected.</p>'
 f'<p style="font-size:38px; line-height:1.25; color:{INK}"><span style="font-family:{MONO}; font-size:26px; font-weight:700; color:{ACCD}">UNLOCKS </span>A game opened daily can collect it.</p></div></div>'
 + phone('scoop',310,551,'Night scoop, played on a day off (gameplay)') + '</div>',
 'What we noticed: people open job apps only when they need money, maybe once a week. They open a game every day. What is missing is not more profile fields; it is behavior over time. A daily game turns each tap into a consented job signal, and a tired cat can stop people from overworking, which an app warning never does. The week above is an illustration of the pattern, not measured data.', 32)
# 04 solution
steps=[('jobs','1  PICK','Shifts that fit'),('work','2  WORK','Gets tired with you'),('scoop','3  NIGHT','Scoop orbs'),('hatch','4  MORNING','Hatch rewards')]
st=''.join(f'<div style="display:flex; flex-direction:column; gap:12px; align-items:center">{phone(g,196,348,a)}<p style="font-family:{MONO}; font-size:26px; font-weight:700; color:{ACCD}">{l}</p><p style="font-size:32px; font-weight:700; text-align:center; color:{INK}">{a}</p></div>' for g,l,a in steps)
S['solution']=sec('solution','04','SOLUTION OVERVIEW','A cat that brings shifts and knows when to stop.',
 f'<div style="display:flex; gap:20px; align-items:center"><p style="font-family:{MONO}; font-size:26px; font-weight:700; color:{ACCD}">WHO IT IS FOR</p><p style="font-size:34px; font-weight:700; color:{INK}">Spot workers · their shops · Recruit</p></div>'
 + f'<div style="display:flex; justify-content:space-between; align-items:flex-start; background:{CARD}; padding:28px 36px; border-radius:6px">{st}'
 + f'<div style="display:flex; flex-direction:column; gap:12px; align-items:center"><img src="/_blob/{G["recruit"]}" alt="Recruit view: at-risk shops and the reasons (live recording)" style="width:440px; height:368px; object-fit:cover; border-radius:12px; background:{INK}"><p style="font-family:{MONO}; font-size:26px; font-weight:700; color:{ACCD}">5  RECRUIT VIEW</p><p style="font-size:32px; font-weight:700; text-align:center; color:{INK}">Who fits, as data</p></div></div>',
 'Your cat brings three or four shifts that fit. During your real shift it works too, and when you overdo it, it says: let\'s both head home. At night you scoop glowing orbs; in the morning they hatch. That is why people open it on days they are not looking for work. Every moment becomes a signal in the Recruit view.', 28)
# 04b wins
def win(img,alt,role,gain,fit="cover"):
    return (f'<div style="display:flex; flex-direction:column; gap:16px; background:{CARD}; padding:24px; border-radius:8px; border-top:8px solid {ACCD}">'
            f'<img src="{img}" alt="{alt}" style="width:452px; height:300px; object-fit:{fit}; border-radius:8px; background:{INK}">'
            f'<h3 style="font-family:{SANS}; font-size:48px; font-weight:800; color:{INK}">{role}</h3>'
            f'<p style="font-size:34px; font-weight:600; line-height:1.25; color:{BODY}">{gain}</p></div>')
arr=f'<p style="font-family:{SANS}; font-size:64px; font-weight:800; color:{ACCD}; text-align:center; align-self:center">→</p>'
loop=['Play daily','Signals','Better matches','People stay','Better shifts']
lp=f'<p style="font-size:32px; font-weight:800; color:{ACC}">→</p>'.join(f'<p style="font-size:32px; font-weight:700; color:#FFFFFF">{x}</p>' for x in loop)
S['wins']=sec('wins','04','SOLUTION OVERVIEW · WHAT CHANGES','Workers, shops and Recruit all come out ahead.',
 f'<div style="display:grid; grid-template-columns:1fr 56px 1fr 56px 1fr; gap:6px; align-items:stretch">'
 + win(f'/_blob/{G["work"]}','Worker and cat on a shift (gameplay)','Workers','Shifts that fit, and a cat that says stop')
 + arr + win(SHOP,'Shop console: today\'s shifts, gaps and chats','Shops','People who show up and come back')
 + arr + win(f'/_blob/{G["recruit"]}','Recruit view (live recording)','Recruit','Fit-and-stay data after the hire')
 + f'</div><div style="display:flex; gap:20px; align-items:center; justify-content:center; background:{INK}; padding:22px 28px; border-radius:6px">{lp}<p style="font-size:34px; font-weight:800; color:{ACC}">↺</p></div>',
 'What changes for each side. Workers get shifts that fit, in-game rewards, and a cat that tells them to go home. Shops get people who show up and come back, and an island that grows only from good reviews. Recruit gets fit-and-stay signals after the hire and a daily front door for its listings. Each gain feeds the next: play, signals, better matches, people who stay, better shifts.', 28)
# 05 impact
def side(n,cap,lb): return f'<div style="display:flex; flex-direction:column; gap:10px; background:{INK}; padding:30px 34px; border-radius:6px"><p style="font-family:{SANS}; font-size:88px; font-weight:800; line-height:1; color:#FFFFFF">{n}</p><p style="font-size:30px; line-height:1.25; color:#E4E7EF">{cap}</p>{tag(lb)}</div>'
S['impact']=sec('impact','05','QUANTIFIED IMPACT','1% better matching in spot work ≈ ¥1.35B a year.',
 f'<div style="display:grid; grid-template-columns:1fr 520px; gap:40px; align-items:stretch">'
 f'<div style="display:flex; flex-direction:column; gap:22px; justify-content:center; background:{INK}; padding:44px 52px; border-radius:6px">'
 f'<p style="font-family:{MONO}; font-size:26px; font-weight:700; color:#FFFFFF">01   PRIMARY NUMBER</p>'
 f'<p style="font-family:{SANS}; font-size:210px; font-weight:800; line-height:0.95; letter-spacing:-4px; color:#FFFFFF">¥1.35B</p>'
 f'<p style="font-size:40px; color:#E4E7EF">a year, if matching improves 1% (≈ $9M)</p>'
 f'<p style="font-family:{MONO}; font-size:44px; font-weight:700; color:{ACC}">¥134.7B × 1% = ¥1.35B</p>{tag("ILLUSTRATIVE")}</div>'
 f'<div style="display:flex; flex-direction:column; gap:22px">' + side('¥14.6B','same 1%, all of Recruit HR Tech','ILLUSTRATIVE') + side('≈ 9%','spot work vs. HR Tech revenue','CALCULATED') + '</div></div>'
 + src('Spot-work market ¥134.7B: Yano Research Institute (FY2025 est.). HR Tech revenue ¥1,458.4B: Recruit Holdings FY2025. Assumes revenue moves 1:1 with match quality; the pilot tests the 1%.'),
 'Recruit HR Technology made 1.46 trillion yen last year. Spot-work matching in Japan is 134.7 billion, about nine percent of that. If signals only we can see lift matching there by one percent, that is about 1.35 billion yen a year; across all of HR Technology, 14.6 billion. This is an illustration, not a forecast. The pilot finds the real number.', 28)
# 06 different
def dot(on,c): return f'<div style="width:64px; height:64px; border-radius:32px; background:{c if on else "#FFFFFF"}; border:4px solid {c if on else LINE}"></div>'
cols=['BEFORE','APPLY','SHIFT','AFTER']
def drow(name,ons,c,bold=False):
    return f'<div style="display:grid; grid-template-columns:280px repeat(4, 1fr); align-items:center; padding:18px 0; border-top:2px solid {LINE}"><p style="font-size:38px; font-weight:{800 if bold else 600}; color:{c if bold else INK}">{name}</p>' + ''.join(f'<div style="display:flex; justify-content:center">{dot(o,c)}</div>' for o in ons) + '</div>'
hdr=f'<div style="display:grid; grid-template-columns:280px repeat(4, 1fr); align-items:center"><p style="font-family:{MONO}; font-size:24px; font-weight:700; color:{INK}">WHAT EACH SEES</p>' + ''.join(f'<p style="font-family:{MONO}; font-size:28px; font-weight:700; text-align:center; color:{MUT}">{c}</p>' for c in cols) + '</div>'
S['different']=sec('different','06','WHAT MAKES THIS DIFFERENT?','AI can write applications. It can\'t show up every day.',
 f'<div style="display:grid; grid-template-columns:1fr 300px; gap:48px; align-items:start"><div style="display:flex; flex-direction:column; gap:22px">'
 f'<div style="display:flex; flex-direction:column; gap:0px; background:{CARD}; padding:28px 36px; border-radius:6px"><p style="font-family:{MONO}; font-size:26px; font-weight:700; color:{ACCD}; padding:0 0 16px 0">HOW IT IS DIFFERENT</p>{hdr}'
 + drow('Spot apps',[False,True,False,False],'#6B7080') + drow('Job boards',[True,True,False,False],'#6B7080') + drow('Paw Time',[True,True,True,True],ACCD,True) + '</div>'
 f'<div style="display:flex; gap:24px; align-items:center; background:{INK}; padding:26px 34px; border-radius:6px"><p style="font-family:{MONO}; font-size:24px; font-weight:700; color:{ACC}; width:230px">HARD TO COPY</p><p style="font-size:36px; font-weight:700; line-height:1.25; color:#FFFFFF">A daily habit comes from a character people love.</p></div></div>'
 + phone('island',280,498,'Coming back daily to build the island (gameplay)') + '</div>',
 'Spot-work apps see the application. Job boards also see searches before it. Both go silent during and after the shift. Paw Time is opened every day for the cat, so it sees all four moments. That daily habit is the hard part to copy, and trust is designed in: shops never get a score on a person, only groups of five or more.')
def chips(l,items,dark=False):
    bg=INK if dark else '#FFFFFF'; c='#FFFFFF' if dark else INK
    return f'<div style="display:flex; gap:14px; align-items:center; flex-wrap:wrap"><p style="width:190px; font-family:{MONO}; font-size:26px; font-weight:700; color:{ACCD}">{l}</p>' + ''.join(f'<p style="font-size:30px; font-weight:700; color:{c}; background:{bg}; padding:10px 20px; border-radius:30px; border:2px solid {LINE}">{x}</p>' for x in items) + '</div>'
# 07
svg=f'''<svg aria-label="Data flow: the game on the phone sends only allow-listed events to the Paw Time API, which rejects free text; events are stored, aggregated with a 5-person minimum, and shown in the Recruit view and shop console; shops post shifts back into the game" viewBox="0 0 1600 420" width="1560" height="410" xmlns="http://www.w3.org/2000/svg" font-family="Inter, Arial, sans-serif">
<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0L10 5L0 10z" fill="{INK}"/></marker><marker id="b" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0L10 5L0 10z" fill="{ACCD}"/></marker></defs>
<g fill="#FFFFFF" stroke="{INK}" stroke-width="2">
<rect x="10" y="110" width="300" height="160" rx="10"/><rect x="420" y="110" width="330" height="160" rx="10"/><rect x="860" y="110" width="300" height="160" rx="10"/>
<rect x="1270" y="10" width="320" height="150" rx="10"/><rect x="1270" y="220" width="320" height="150" rx="10"/></g>
<g fill="{INK}" font-size="30" font-weight="800"><text x="160" y="172" text-anchor="middle">Worker's phone</text><text x="585" y="172" text-anchor="middle">Paw Time API</text><text x="1010" y="172" text-anchor="middle">Event store</text><text x="1430" y="72" text-anchor="middle">Recruit view</text><text x="1430" y="282" text-anchor="middle">Shop console</text></g>
<g fill="{MUT}" font-size="24"><text x="160" y="212" text-anchor="middle">Godot web game</text><text x="160" y="244" text-anchor="middle">consent card</text>
<text x="585" y="212" text-anchor="middle">allow-listed events</text><text x="585" y="244" text-anchor="middle">free text rejected</text>
<text x="1010" y="212" text-anchor="middle">Blob → Postgres</text><text x="1010" y="244" text-anchor="middle">k ≥ 5 aggregates</text>
<text x="1430" y="112" text-anchor="middle">fit, return, at-risk</text><text x="1430" y="322" text-anchor="middle">results + groups of 5+</text></g>
<g stroke="{INK}" stroke-width="3" fill="none" marker-end="url(#a)"><path d="M310 190H415"/><path d="M750 190H855"/><path d="M1160 170L1265 90"/><path d="M1160 210L1265 290"/></g>
<path d="M1270 340C1000 410 400 410 160 275" stroke="{ACCD}" stroke-width="3" fill="none" stroke-dasharray="10 8" marker-end="url(#b)"/>
<text x="760" y="412" fill="{ACCD}" font-size="24" font-weight="700" text-anchor="middle">shops post shifts → your cat brings them</text>
</svg>'''
def nlab(t,sub): return f'<div style="display:flex; flex-direction:column; gap:2px; align-items:center"><p style="font-family:{MONO}; font-size:24px; font-weight:700; color:{ACCD}">{t}</p><p style="font-size:24px; color:{MUT}">{sub}</p></div>'
def chk(ok,t): return f'<div style="display:flex; gap:14px; align-items:center"><p style="width:44px; height:44px; border-radius:22px; background:{"#3E9A6A" if ok else "#D9534A"}; color:#FFFFFF; font-size:30px; font-weight:800; text-align:center; line-height:1.45">{"✓" if ok else "✕"}</p><p style="font-size:30px; font-weight:700; color:#FFFFFF">{t}</p></div>'
ar=f'<p style="font-family:{SANS}; font-size:72px; font-weight:800; color:{ACCD}; align-self:center">→</p>'
flow=(f'<div style="display:flex; justify-content:space-between; align-items:center; background:{CARD}; padding:26px 32px; border-radius:6px">'
 + f'<div style="display:flex; flex-direction:column; gap:12px; align-items:center">{phone("work",210,373,"Worker\'s phone: the game on a shift (gameplay)")}{nlab("WORKER\'S PHONE","Godot web game")}</div>' + ar
 + f'<div style="display:flex; flex-direction:column; gap:12px; align-items:center"><div style="display:flex; flex-direction:column; gap:18px; background:{INK}; padding:30px 30px; border-radius:10px">{chk(True,"Consent first")}{chk(True,"Fixed event list")}{chk(False,"Free text")}{chk(False,"Scores on people")}</div>{nlab("PAW TIME API","Hono + zod")}</div>' + ar
 + f'<div style="display:flex; flex-direction:column; gap:12px; align-items:center"><div style="display:flex; flex-direction:column; gap:6px; align-items:center; background:{INK}; padding:28px 34px; border-radius:10px"><p style="font-family:{SANS}; font-size:88px; font-weight:800; line-height:1; color:#FFFFFF">5+</p><p style="font-size:28px; font-weight:700; color:#E4E7EF">people per group</p></div>{nlab("EVENT STORE","aggregates only")}</div>' + ar
 + f'<div style="display:flex; flex-direction:column; gap:16px"><div style="display:flex; flex-direction:column; gap:6px; align-items:center"><img src="/_blob/{G["recruit"]}" alt="Recruit view (live recording)" style="width:340px; height:190px; object-fit:cover; border-radius:8px; background:{INK}"><p style="font-family:{MONO}; font-size:24px; font-weight:700; color:{ACCD}">RECRUIT VIEW</p></div><div style="display:flex; flex-direction:column; gap:6px; align-items:center"><img src="{SHOP}" alt="Shop console" style="width:340px; height:190px; object-fit:cover; border-radius:8px; background:{INK}"><p style="font-family:{MONO}; font-size:24px; font-weight:700; color:{ACCD}">SHOP CONSOLE</p></div></div>'
 + '</div>')
S['technical']=sec('technical','07','TECHNICAL DESIGN','Only fixed, consented events leave the phone.',
 flow + chips('STACK',['Godot 4.7 · WebGL2','TypeScript','Hono + zod','Vercel','Next.js 15','Chart.js']),
 'The game only sends events from a fixed list, after a consent card. The API rejects free text and never builds scores on individuals. Events are stored and aggregated in groups of five or more before a shop sees anything. Recruit sees fit and return signals; shops see results and groups.', 24)
# 08
def hz(i,t,tf,m,img,alt): return f'<div style="flex:1; display:flex; flex-direction:column; gap:14px; background:{INK}; padding:22px 24px 30px 24px; border-radius:6px; border-top:8px solid {ACC}"><img src="{img}" alt="{alt}" style="width:484px; height:190px; object-fit:cover; border-radius:6px; background:#000000"><p style="font-family:{MONO}; font-size:26px; font-weight:700; color:#FFFFFF">{i}   {t} · <span style="color:{ACC}">{tf}</span></p><p style="font-size:40px; font-weight:700; line-height:1.2; color:#FFFFFF">{m}</p></div>'
S['roadmap']=sec('roadmap','08','FUTURE ROADMAP','From five shops to Recruit\'s daily front door.',
 f'<div style="display:flex; gap:28px">'
 + hz('01','NEAR TERM','0–3 months','Pilot: 3–5 shops, 4 weeks',SHOP,'Shop console for pilot shops')
 + hz('02','MEDIUM TERM','3–12 months','One city, Recruit listings, +1% target',f'/_blob/{G["recruit"]}','Recruit view (live recording)')
 + hz('03','LONG TERM','1–3 years','Inside Indeed matching, Japan + US',f'/_blob/{G["island"]}','Island gameplay') + '</div>'
 + f'<div style="display:flex; gap:28px; align-items:stretch"><div style="flex:1; display:flex; flex-direction:column; justify-content:center; gap:12px; background:{CARD}; padding:28px 36px; border-radius:6px"><p style="font-family:{MONO}; font-size:24px; font-weight:700; color:{ACCD}">FASTEST ACCELERATOR</p><p style="font-size:40px; font-weight:700; line-height:1.25; color:{INK}">Five pilot shops + Recruit listings</p></div>'
 + f'<div style="display:flex; gap:24px; align-items:center; background:{INK}; padding:20px 28px; border-radius:6px"><img src="{QR}" alt="QR code: paw-time-play.vercel.app" style="width:170px; height:170px; object-fit:contain; border-radius:6px"><div style="display:flex; flex-direction:column; gap:8px"><p style="font-family:{MONO}; font-size:24px; font-weight:700; color:{ACC}">PLAY IT NOW</p><p style="width:380px; font-size:26px; line-height:1.35; color:#FFFFFF">paw-time-play.vercel.app</p><p style="width:380px; font-size:24px; line-height:1.35; color:{ACC2}">3-minute demo on the title screen</p></div></div></div>',
 'Near term: a four-week pilot with three to five shops, to test whether next-day return predicts who comes back. Then Recruit listings in one city, aiming for one percent better fill-and-stay. Long term, these signals inside Indeed matching. What would speed this up most: five pilot shops and access to Recruit listings. Scan the code to play. Paw Time. Let\'s work together.')
for k,v in S.items(): open(f'slides/{k}.html','w').write(v)
d=json.load(open('deck.json'))
d['order']=['cover','problem','insight','solution','wins','impact','different','technical','roadmap','data','view','day','tired','cats','island','shops']
json.dump(d,open('deck.json','w'),ensure_ascii=False,indent=1)
