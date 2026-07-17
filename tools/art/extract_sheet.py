#!/usr/bin/env python
"""Turn a PRE-KEYED animation SHEET (transparent background, an NxM grid of
labelled frames) into engine-ready horizontal clip strips for Crownless.
See tools/art/README.md for the full pipeline + rationale.

Pipeline per frame:
  1. mask = alpha > 40 (transparent bg keys itself).
  2. drop baked frame-number glyphs: small gold blobs that FLOAT in empty space
     (embedded gold armour / blonde hair is spared, else it leaves holes).
  3. keep the SINGLE largest connected component = the character; every label
     / number / detached FX blob is separate and smaller, so this removes them
     with no geometric masking (=> heads are never clipped).
  4. SOLIDIFY: fill interior holes + force alpha fully opaque so no background
     bleeds through the sprite (the fix for grass showing through as green).
  5. mirror each frame to face LEFT (Crownless's faces_left art contract),
     preserving column/time order.
  6. re-center into a uniform GLOBAL square, feet-aligned to the bottom.

Frame 0 (leftmost) is dropped because it alone carries the gold ROW-NAME label
(a pose whose weapon reaches left can merge it into the figure) -> 7 clean
frames. Rows are mapped to clip names via --names (comma list, one per row).
"""
import os, argparse
import numpy as np
from PIL import Image
from scipy import ndimage

def bands(v, thr, gap=6):
    on = v > thr; out=[]; s=None; run=0
    for i,b in enumerate(on):
        if b:
            if s is None: s=i
            run=0
        else:
            if s is not None:
                run+=1
                if run>gap: out.append((s,i-run)); s=None
    if s is not None: out.append((s,len(on)-1))
    return out

def solidify(crop, m):
    # Kill grass bleed-through: the kept silhouette `m` becomes FULLY opaque and
    # any interior holes are filled, so nothing behind the sprite shows through
    # (semi-transparent body/edge pixels were tinting green over grass). Interior
    # holes borrow the nearest opaque pixel's colour so they aren't black.
    solid = ndimage.binary_fill_holes(m)
    out = crop.copy()
    need = solid & (~m)
    if need.any():
        idx = ndimage.distance_transform_edt(~m, return_distances=False, return_indices=True)
        out[need] = crop[idx[0][need], idx[1][need]]
    # De-halo: a light AA rim survives on very dark sprites (assassin) as a white
    # outline. Recolour outer-ring pixels that are notably LIGHTER than their
    # inner neighbour to that neighbour's colour — twice, for a 2px halo. Only a
    # light rim triggers it, so already-clean (edge<=body) sprites are untouched.
    for _ in range(2):
        inner = ndimage.binary_erosion(solid)
        ring = solid & ~inner
        if not (ring.any() and inner.any()):
            break
        iy, ix = ndimage.distance_transform_edt(~inner, return_distances=False, return_indices=True)
        ry, rx = np.where(ring)
        nb = out[iy[ry, rx], ix[ry, rx]]
        lighter = out[ry, rx][:, :3].astype(int).sum(1) > nb[:, :3].astype(int).sum(1) + 55
        out[ry[lighter], rx[lighter], :3] = nb[lighter, :3]
        solid = inner
    out[:,:,3] = np.where(ndimage.binary_fill_holes(m), 255, 0).astype(np.uint8)
    return out


def pick_character(sub):
    # sub: alpha mask of one cell. Pick the CHARACTER, not FX. Largest-CC fails
    # when a frame's projectile bolt or summon pool is bigger than the figure
    # (warlock turned into a bolt / a skull-puddle). The character is instead the
    # component that is TALL, horizontally CENTERED, and standing on the feet
    # baseline; a bolt is a thin off-centre streak and a pool is a short puddle,
    # so a character-likeness score beats them without dropping real limbs/weapons.
    # We label a CLOSED mask so a held part detached by a 1-2px anti-alias gap (a
    # paladin shield behind the arm) stays ONE component instead of flickering
    # away frame to frame; distant FX stays separate (closing radius is tiny).
    # Pad before closing: erosion treats the array border as empty, so a figure
    # touching the cell edge (feet at the bottom) would lose those pixels — that
    # cut the paladin's lower legs. Padding keeps the border out of the erosion.
    P = 3
    closed = ndimage.binary_closing(np.pad(sub, P), iterations=2)[P:-P, P:-P]
    lbl,n = ndimage.label(closed)
    if n==0: return None
    H,W = sub.shape
    best=None; best_score=-1e18
    for k in range(1,n+1):
        ys,xs = np.where(lbl==k)
        if len(ys) < 20: continue                     # speck
        h = ys.max()-ys.min()+1
        cx = 0.5*(xs.min()+xs.max())
        score = h - 1.2*abs(cx - W/2.0) - 0.6*(H-1-ys.max())
        if score > best_score:
            best_score=score; best=k
    if best is None:
        sizes = ndimage.sum(np.ones_like(lbl), lbl, range(1,n+1))
        best = int(np.argmax(sizes))+1
    # Re-include the figure's other FRAGMENTS: a low-alpha neck/waist can split
    # a character into separate head / torso / legs components, and keeping only
    # `best` dropped the head or the legs (the paladin flicker/cut). Keep any
    # sizeable component that OVERLAPS the main figure's bbox (grown a little) —
    # head sits just above, legs just below. Distant FX (a bolt off to the side)
    # and labels don't overlap the figure's column, so they still stay out.
    ys,xs = np.where(lbl==best)
    # Reach DOWN (dropped legs sit below the torso) and sideways, but NOT up:
    # nothing wanted floats above the head, but frame-number labels do — so an
    # upward reach would wrongly re-grab them.
    my0,my1,mx0,mx1 = ys.min()+2, ys.max()+8, xs.min()-4, xs.max()+4
    keep = {best}
    for k in range(1,n+1):
        if k==best: continue
        yk,xk = np.where(lbl==k)
        if len(yk) < 40: continue                     # a body part is sizeable; specks/label bits aren't
        if yk.min()<=my1 and yk.max()>=my0 and xk.min()<=mx1 and xk.max()>=mx0:
            keep.add(k)
    # Return the CLOSED components (not raw sub) so thin internal transparent
    # SEAMS — mid-alpha armour detail the cutoff sliced through — are filled too.
    return closed & np.isin(lbl, list(keep))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--in',dest='inp',required=True)
    ap.add_argument('--out',dest='out',required=True)
    ap.add_argument('--class',dest='cls',required=True)
    ap.add_argument('--names',dest='names',default='',help='comma list: row i -> clip name (idle,walk,run,attack,...)')
    ap.add_argument('--pad',dest='pad',type=float,default=1.06,help='square padding factor around the widest/tallest frame')
    ap.add_argument('--ncol',dest='ncol',type=int,default=8,help='frames per row')
    ap.add_argument('--nomirror',dest='nomirror',action='store_true',help='keep source facing (directional sheets encode their own direction)')
    ap.add_argument('--keepall',dest='keepall',action='store_true',help='keep frame 0 (use when col 0 has no row-name label, e.g. directional sheets)')
    ap.add_argument('--drop',dest='drop',default='',help='cut FX-only frames: comma list of clip:frameindex (post-extraction indices), e.g. attack2:3')
    ap.add_argument('--rowgap',dest='rowgap',type=int,default=3,help='empty rows needed to split two clip rows (lower if rows merge)')
    ap.add_argument('--flatten',dest='flatten',default='',help='pack ALL rows into one strip named <class>_<this> (row-major); for directional sheets = 8 dirs x K frames')
    ap.add_argument('--alpha',dest='alpha',type=int,default=90,help='alpha cutoff for the silhouette; raise to cut inside a light AA halo (white-rim fix)')
    ap.add_argument('--key',dest='key',type=int,default=45,help='colour-distance for auto bg-key on opaque navy sheets; lower to spare dark pixels (boot soles) close to the bg')
    a=ap.parse_args()
    dropmap={}
    for tok in filter(None, (t.strip() for t in a.drop.split(','))):
        cn,_,fi = tok.partition(':')
        dropmap.setdefault(cn, []).append(int(fi))
    os.makedirs(a.out,exist_ok=True)
    im = np.asarray(Image.open(a.inp).convert('RGBA')).copy()   # uint8 pixel data
    # Opaque-background sheets (the ORIGINAL navy sheets, no alpha) need the
    # background keyed to transparent before the alpha silhouette works. Auto:
    # sample the four corners for the bg colour, drop pixels close to it.
    if (im[:,:,3] > 200).mean() > 0.9:
        k=12
        cor=np.concatenate([im[:k,:k].reshape(-1,4), im[:k,-k:].reshape(-1,4),
                            im[-k:,:k].reshape(-1,4), im[-k:,-k:].reshape(-1,4)])
        bgc=np.median(cor[:,:3],axis=0)
        d=np.abs(im[:,:,:3].astype(int)-bgc).sum(2)
        im[d < a.key, 3] = 0
    alpha = im[:,:,3]
    fg = alpha > a.alpha
    H,W = fg.shape

    # Kill leftover frame-number glyphs: small gold blobs with digit-like
    # dimensions. But a number FLOATS in empty space while gold armour / blonde
    # hair is EMBEDDED in the figure, so only remove a candidate whose immediate
    # surroundings are mostly transparent -> spares paladin trim & archer hair
    # (previously these were eaten, leaving holes the grass showed through).
    fw = W / max(1, a.ncol)                            # frame width -> scale the digit gate
    r,g,b = im[:,:,0].astype(int), im[:,:,1].astype(int), im[:,:,2].astype(int)
    gold = fg & (r>150) & (g>120) & (b<150) & ((r-b)>45) & (g>=b)
    glbl,gn = ndimage.label(gold)
    for k in range(1,gn+1):
        ys,xs = np.where(glbl==k)
        h=ys.max()-ys.min()+1; w=xs.max()-xs.min()+1
        if not (len(ys) < 0.014*fw*fw and h < 0.19*fw and w < 0.20*fw):
            continue                                  # too big to be a digit (gate scales with resolution)
        P=3
        y0,y1=max(0,ys.min()-P),min(H,ys.max()+1+P)
        x0,x1=max(0,xs.min()-P),min(W,xs.max()+1+P)
        blob=(glbl[y0:y1, x0:x1]==k)
        ring=ndimage.binary_dilation(blob, iterations=2) & ~blob
        opq_frac = (fg[y0:y1, x0:x1] & ring).sum() / max(1, ring.sum())
        if opq_frac < 0.30:                           # floating in transparency = label
            fg[glbl==k] = False

    names=[s.strip() for s in a.names.split(',')] if a.names else []

    rb = bands(fg.sum(axis=1), fg.sum(axis=1).max()*0.04, gap=a.rowgap)
    rb = [(s,e) for (s,e) in rb if e-s > 18]
    print(f'{a.cls}: {len(rb)} rows')
    NCOL=a.ncol; pitch=W/NCOL
    # Frame 0 (leftmost cell) is normally the ONLY cell carrying the gold
    # row-name label; dropping it yields clean frames with zero risk to the
    # figure. Directional sheets (--keepall) have no such label and every cell
    # is a wanted pose, so keep them all.
    cols = range(NCOL) if a.keepall else range(1, NCOL)

    # PASS 1: cut each frame's character (mirrored to face left unless --nomirror)
    grid=[]
    for ri,(y0,y1) in enumerate(rb):
        row=[]
        for c in cols:
            x0=int(round(c*pitch)); x1=int(round((c+1)*pitch))
            sub=fg[y0:y1+1, x0:x1+1]
            if sub.sum() < 20: row.append(None); continue
            m=pick_character(sub)
            if m is None: row.append(None); continue
            cell=im[y0:y1+1, x0:x1+1].copy()
            sld=solidify(cell, m)                     # opaque body, holes filled
            ys,xs=np.where(sld[:,:,3]>0)
            crop=sld[ys.min():ys.max()+1, xs.min():xs.max()+1]
            if not a.nomirror:
                crop=crop[:, ::-1, :]                 # mirror -> face LEFT (order kept)
            row.append(crop)
        # FX-frame substitution: some action frames are JUST the projectile/pool
        # (the character isn't drawn — the game spawns the real effect), which
        # left the warlock flickering into a bolt/skull-puddle. Such a frame's
        # blob is far shorter than the standing figure, so swap any frame under
        # half the row's median height for the nearest real character frame.
        # Skipped for death, whose short collapse frames are intentional.
        nm = names[ri] if ri < len(names) else ''
        hs = sorted(cr.shape[0] for cr in row if cr is not None)
        if nm != 'death' and hs:
            thresh = 0.5 * hs[len(hs)//2]
            good = [i for i,cr in enumerate(row) if cr is not None and cr.shape[0] >= thresh]
            if good and len(good) < len(row):
                for i in range(len(row)):
                    if row[i] is None or row[i].shape[0] < thresh:
                        row[i] = row[min(good, key=lambda g: abs(g-i))].copy()
        # Explicit frame CUTS: for FX-only frames a tall thin arc/beam can't be
        # auto-detected safely, just remove them by index (e.g. --drop attack2:3).
        # Frame count is auto-detected downstream, so a shorter clip just works.
        for j in sorted(dropmap.get(nm, []), reverse=True):
            if 0 <= j < len(row):
                del row[j]
        grid.append(row)

    allf=[f for r in grid for f in r if f is not None]
    gmw=max(f.shape[1] for f in allf); gmh=max(f.shape[0] for f in allf)
    side=int(max(gmw,gmh)*a.pad)

    # --flatten: concatenate every row's frames into ONE strip (row-major). For
    # a directional sheet that's 8 directions x K frames = one 8*K strip the
    # engine slices by direction*K + subframe.
    if a.flatten:
        allf=[f for row in grid for f in row if f is not None]
        strip=Image.new('RGBA',(side*len(allf), side),(0,0,0,0))
        for c,f in enumerate(allf):
            img=Image.fromarray(f,'RGBA')
            strip.paste(img,(c*side+(side-img.width)//2, side-img.height-int(side*0.02)),img)
        strip.save(os.path.join(a.out,f'{a.cls}_{a.flatten}.png'))
        print('done',a.cls,a.flatten,'frames=',len(allf),'side=',side)
        return

    # PASS 2: pack strips, feet-aligned + h-centered (per-row frame count, since
    # a --drop row can be shorter than the others)
    qa=[]
    for ri,row in enumerate(grid):
        strip=Image.new('RGBA',(side*len(row),side),(0,0,0,0))
        for c,f in enumerate(row):
            if f is None: continue
            img=Image.fromarray(f,'RGBA')
            px=c*side+(side-img.width)//2
            py=side-img.height-int(side*0.02)
            strip.paste(img,(px,py),img)
        strip.save(os.path.join(a.out,f'{a.cls}_row{ri:02d}.png'))
        qa.append(strip)
        nm = names[ri] if ri < len(names) else ''
        if nm=='idle':
            strip.save(os.path.join(a.out,f'{a.cls}_anim.png'))
            strip.crop((0,0,side,side)).save(os.path.join(a.out,f'{a.cls}.png'))
        elif nm=='walk':
            strip.save(os.path.join(a.out,f'{a.cls}_walk.png'))
        elif nm:
            strip.save(os.path.join(a.out,f'{a.cls}_{nm}.png'))
    if qa:
        wmax=max(s.width for s in qa); htot=sum(s.height for s in qa)
        sheet=Image.new('RGBA',(wmax,htot),(60,64,74,255)); y=0
        for s in qa: sheet.alpha_composite(s,(0,y)); y+=s.height
        sheet.convert('RGB').save(os.path.join(a.out,f'{a.cls}_QA.png'))
    print('done',a.cls,'side=',side,'gmw=',gmw,'gmh=',gmh)

if __name__=='__main__': main()
