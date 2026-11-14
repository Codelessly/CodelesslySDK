#!/usr/bin/env python3
"""Writes polish/gallery: the illustrations large, to look at them."""
import json, os
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = f'{HERE}/gallery'
os.makedirs(out, exist_ok=True)
json.dump({"schema":3,"pages":["art.json","gallery.json"],"designSystem":"../../../../design_systems/skip"},open(f'{out}/site.json','w'))
nodes={"art":{"type":"canvas","slots":{"body":"col"},"layout":{"width":800,"height":1100},"decoration":{"fills":[{"color":"page"}]}},
"col":{"type":"column","children":["r1","r2","r3"],"layout":{"width":{"fill":0},"height":{"fill":0},"padding":20},"props":{"spacing":20,"scrollable":True}}}
def cell(id,role,aud,w,h,bg):
    nodes[id+'b']={"type":"row","children":[id],"layout":{"width":w+20,"height":h+20},"props":{"mainAxisAlignment":"center"},"decoration":{"fills":[bg],"radius":24}}
    nodes[id]={"type":"Illustration","layout":{"width":w,"height":h},"props":{"role":role,"audience":aud}}
    return id+'b'
hero={"type":"linear","begin":"topLeft","end":"bottomRight","stops":[{"position":0,"color":"heroA"},{"position":1,"color":"heroB"}]}
row=lambda kids:{"type":"row","children":kids,"layout":{"width":{"hug":0},"height":{"hug":0}},"props":{"spacing":16}}
nodes['r1']=row([cell('ha','hero','adult',350,350,hero),cell('hk','hero','kid',350,350,hero)])
nodes['r2']=row([cell('sa','streak','adult',200,248,{"color":"card"}),cell('sk','streak','kid',200,248,{"color":"card"}),cell('ra','record','adult',200,240,{"color":"goldTint"})])
nodes['r3']=row([cell('ea','empty','adult',350,280,{"color":"card"}),cell('ek','empty','kid',350,280,{"color":"card"})])
json.dump({"schema":3,"roots":["art"],"nodes":nodes},open(f'{out}/art.json','w'),indent=1)
