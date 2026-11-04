import json,math
def s2l(c): return c/12.92 if c<=0.04045 else ((c+0.055)/1.055)**2.4
def l2s(c): c=max(0,min(1,c)); return 12.92*c if c<=0.0031308 else 1.055*c**(1/2.4)-0.055
def hex2ok(h):
    r,g,b=[s2l(int(h[i:i+2],16)/255) for i in (1,3,5)]
    l=(0.4122214708*r+0.5363325363*g+0.0514459929*b)**(1/3)
    m=(0.2119034982*r+0.6806995451*g+0.1073969566*b)**(1/3)
    s=(0.0883024619*r+0.2817188376*g+0.6299787005*b)**(1/3)
    L=0.2104542553*l+0.7936177850*m-0.0040720468*s
    a=1.9779984951*l-2.4285922050*m+0.4505937099*s
    bb=0.0259040371*l+0.7827717662*m-0.8086757660*s
    return L,math.hypot(a,bb),math.atan2(bb,a)
def ok2hex(L,C,H):
    for _ in range(60):
        a,b=C*math.cos(H),C*math.sin(H)
        l=(L+0.3963377774*a+0.2158037573*b)**3; m=(L-0.1055613458*a-0.0638541728*b)**3; s=(L-0.0894841775*a-1.2914855480*b)**3
        r=4.0767416621*l-3.3077115913*m+0.2309699292*s; g=-1.2684380046*l+2.6097574011*m-0.3413193965*s; bl=-0.0041960863*l-0.7034186147*m+1.7076147010*s
        if min(r,g,bl)>=-1e-4 and max(r,g,bl)<=1+1e-4: break
        C*=0.95
    return "#%02X%02X%02X"%tuple(round(l2s(x)*255) for x in (r,g,bl))
def lum(h): r,g,b=[s2l(int(h[i:i+2],16)/255) for i in (1,3,5)]; return .2126*r+.7152*g+.0722*b
def contrast(a,b): x,y=sorted([lum(a),lum(b)]); return (y+.05)/(x+.05)
STEPS=["50","100","200","300","400","500","600","700","800","900","950","975"]
GL=[.985,.965,.925,.87,.76,.64,.54,.44,.34,.255,.195,.155]
AL=[.975,.945,.90,.83,.75,.66,.57,.48,.39,.30,.23,.18]
AK=[.16,.28,.48,.72,.9,1,.95,.85,.72,.58,.46,.38]
def gray(hue_deg,chroma): H=math.radians(hue_deg); return {s:ok2hex(l,chroma*(0.6 if i in(0,11) else 1),H) for i,(s,l) in enumerate(zip(STEPS,GL))}
def acc(h,boost=1.0):
    L,C,H=hex2ok(h); return {s:ok2hex(l,C*k*boost,H) for s,l,k in zip(STEPS,AL,AK)}
grays={ # 染灰：同色相低彩度——每套预设的“墨与纸”
 "sand":gray(70,.014),"mauve":gray(355,.016),"slate":gray(255,.016),
 "navy":gray(258,.032),"graphite":gray(220,.007),"char":gray(25,.018),"olive":gray(110,.014)}
accents={
 "copper":acc("#B56C4C"),"brass":acc("#B08D57"),"amber":acc("#D9A441"),"clay":acc("#C46A4A",.9),
 "persimmon":acc("#E0708A"),"rose":acc("#C27E8A"),"oxblood":acc("#A63A4A"),"plum":acc("#8A5A86"),
 "indigo":acc("#5B6BA8"),"aegean":acc("#3A8FB7"),"cyan":acc("#2FB7D6"),"teal":acc("#26A69A"),
 "sage":acc("#5E8B7E"),"moss":acc("#7A8B4E"),
 "ok":acc("#4E8B62"),"warn":acc("#C08A3E"),"err":acc("#B5453F"),"info":acc("#4F7FAF")}
json.dump({"grays":grays,"accents":accents},open("/tmp/atl/palette.json","w"),indent=1)
