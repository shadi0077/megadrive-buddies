from PIL import Image
import os, json
D="assets/frames"
KEY=(0,255,255)
rows=[]
for i in range(705):
    p=f"{D}/{i:04d}.png"
    im=Image.open(p).convert("RGB")
    # mask of non-key pixels
    r,g,b=im.split()
    import PIL.ImageChops as C
    # build alpha: 0 where key
    px=im.load()
    W,H=im.size
    minx,miny,maxx,maxy=W,H,-1,-1
    cnt=0
    for y in range(H):
        for x in range(W):
            if px[x,y]!=KEY:
                cnt+=1
                if x<minx:minx=x
                if x>maxx:maxx=x
                if y<miny:miny=y
                if y>maxy:maxy=y
    if maxx<0: rows.append((i,0,0,0,0,0,0))
    else: rows.append((i,minx,miny,maxx-minx+1,maxy-miny+1,cnt,(maxx-minx+1)*(maxy-miny+1)))
json.dump(rows,open("tools/bbox.json","w"))
for r in rows[:0]: pass
print("done")
