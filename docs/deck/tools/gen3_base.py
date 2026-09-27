import json
BG="/_blob/e79bfc7b8c9a910d999b7425a8010127"; LOGO="/_blob/4cdebf9920817b95cc5ac10a6a4779c2"; PAW="/_blob/0ceb0e08636a0cd02919166b638d8064"; QR="/_blob/5cffd8864869ee180a41fbaf1f3f679e"; SHOP="/_blob/919bc70f9cd5186f990f18e5070b5536"
G=dict(jobs="4a8937d465b59c3f5634e86dafa67e12",work="e55c40500f4112be6b29838c6417d54d",scoop="3956ba8e89e1893f89a71f5af9f6a844",hatch="d70b5c15f21995927d0a6acdf2a7f780",island="b4e2fe985f9362f73782824683b24cf3",recruit="7a4437a6ec4fd5a730d04387496a269f",title="e58ee4e51f82da8dcde516f9c9d5d1e7")
INK="#1C1E23"; MUT="#5E6472"; PANEL="#DCDDE0"; CARD="#F2F3F5"; ACC="#8499D7"; ACCD="#3F52A3"; ACC2="#A6B1CD"; LINE="#C5C8CF"; BODY="#2B2E36"
MONO="'Roboto Mono', 'Courier New', monospace"; SANS="'Inter', Arial, sans-serif"
def lockup():
    return (f'<div style="position:absolute; right:64px; bottom:14px; display:flex; gap:20px; align-items:center">'
            f'<img src="{PAW}" alt="Paw Time" style="width:188px; height:52px; object-fit:contain">'
            f'<div style="width:2px; height:34px; background:{ACC2}"></div>'
            f'<img src="{LOGO}" alt="Innovation Cup" style="width:236px; height:36px; object-fit:contain"></div>')
def frame(n):
    return (f'<img src="{BG}" alt="" style="position:absolute; left:0px; top:0px; width:1920px; height:1080px; object-fit:cover">'
            f'<div style="position:absolute; left:72px; top:64px; width:1776px; height:920px; background:{PANEL}; border-radius:6px"></div>'
            f'<p style="position:absolute; right:72px; top:16px; width:200px; text-align:right; font-family:{MONO}; font-size:24px; font-weight:700; color:{ACC2}">{n} / 08</p>'
            f'<p style="position:absolute; left:72px; bottom:24px; width:700px; font-family:{MONO}; font-size:24px; letter-spacing:1px; color:{ACC2}">TEAM DRY GRAPE</p>' + lockup())
def head(n,sec,title):
    return (f'<div style="display:flex; flex-direction:column; gap:14px">'
            f'<p style="font-family:{MONO}; font-size:30px; font-weight:700; letter-spacing:1px; color:{ACCD}">{n} · {sec}</p>'
            f'<h2 style="font-family:{SANS}; font-size:60px; font-weight:800; line-height:1.1; letter-spacing:-1px; color:{INK}">{title}</h2></div>')
def sec(id_,n,sec_,title,body,notes,gap=32):
    return (f'<section id="{id_}" data-transition="fade" style="background:#0A0B0E; color:{INK}; font-family:{SANS}; padding:128px 128px 160px; display:flex; flex-direction:column; gap:{gap}px">\n'
            + frame(n) + '\n' + head(n,sec_,title) + '\n' + body + f'\n<aside>{notes}</aside>\n</section>\n')
def lab(t,w=300,c=INK): return f'<p style="width:{w}px; font-family:{MONO}; font-size:24px; font-weight:700; letter-spacing:1px; color:{c}">{t}</p>'
def row(l,t,w=300,fs=28): return f'<div style="display:flex; gap:32px; align-items:flex-start; border-top:1px solid {LINE}; padding:16px 0 0 0">{lab(l,w)}<p style="flex:1; font-size:{fs}px; line-height:1.4; color:{BODY}">{t}</p></div>'
def tag(t,c=ACC): return f'<span style="font-family:{MONO}; font-size:24px; font-weight:700; color:{c}">[{t}]</span>'
def phone(g,w,h,alt): return f'<div style="background:{INK}; padding:10px; border-radius:36px"><img src="/_blob/{G[g]}" alt="{alt}" style="width:{w}px; height:{h}px; object-fit:cover; border-radius:28px"></div>'
