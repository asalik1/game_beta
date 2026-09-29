"""Reproduce T52a round 2 PNGs and true 1:1 nine-slice review sheets.

Only crops/alpha cleanup/resampling: no procedural painting or material synthesis.
Run from any directory; every output stays in this worktree.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / 'game/assets/ui/frame'
LANCZOS = Image.Resampling.LANCZOS
SPECS = {
    'panel': ('panel_r2.png', (768, 768), (150, 150, 150, 150), (16, 16, 16, 16)),
    'card': ('card_r2_color2.png', (256, 128), (110, 110, 110, 110), (9, 9, 9, 9)),
    'tab_active': ('tab_active_r2_color.png', (160, 32), (80, 84, 80, 59), (5, 5, 5, 5)),
    'tab_idle': ('tab_idle_r2_color3.png', (160, 32), (80, 84, 80, 59), (5, 5, 5, 5)),
    'slot': ('slot_r2_color.png', (48, 48), (115, 115, 115, 115), (6, 6, 6, 6)),
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def clean_crop(path):
    im = Image.open(path).convert('RGBA')
    a = np.array(im)
    a[a[:, :, 3] <= 16] = 0
    a[:, :, 3][a[:, :, 3] >= 245] = 255
    im = Image.fromarray(a)
    box = im.getbbox()
    return im.crop(box), box

def nine(im, size, src, dst=None):
    """Godot STRETCH nine-slice: corners fixed, each edge on its own axis."""
    dst = src if dst is None else dst
    w, h = im.size
    W, H = size
    l, t, r, b = src
    L, T, R, B = dst
    assert w > l+r and h > t+b and W >= L+R and H >= T+B
    xs, ys = (0,l,w-r,w), (0,t,h-b,h)
    xd, yd = (0,L,W-R,W), (0,T,H-B,H)
    out = Image.new('RGBA', size)
    for j in range(3):
        for i in range(3):
            tile = im.crop((xs[i],ys[j],xs[i+1],ys[j+1]))
            tile = tile.resize((xd[i+1]-xd[i],yd[j+1]-yd[j]), LANCZOS)
            out.paste(tile,(xd[i],yd[j]))
    return out

def stats(im, margins=None):
    a = np.array(im)
    hsv = np.array(im.convert('RGB').convert('HSV')).astype(float)
    mask = a[:,:,3] >= 245
    if margins:
        l,t,r,b = margins
        mask[t:im.height-b,l:im.width-r] = False
    vals = hsv[mask]
    return {'hue_degrees': round(float(vals[:,0].mean()*360/255),2),
            'saturation': round(float(vals[:,1].mean()/255),4),
            'value': round(float(vals[:,2].mean()/255),4),
            'sample_pixels': int(mask.sum())}

def build():
    metrics = {}
    for name,(filename,size,src,dst) in SPECS.items():
        path = HERE / 'masters' / filename
        im, box = clean_crop(path)
        final = nine(im,size,src,dst)
        final.save(OUT / (name+'.png'))
        center = np.array(final)[dst[1]:size[1]-dst[3],dst[0]:size[0]-dst[2]]
        assert center[:,:,3].min() == 255, name+' translucent center'
        metrics[name] = {'master': 'masters/'+filename, 'master_sha256': sha(path),
            'raw_size': Image.open(path).size, 'crop_xyxy': box,
            'source_margins_ltrb': src, 'size': size, 'margins_ltrb_px': dst,
            'border_hsv': stats(final,dst), 'center_alpha_min':255,
            'sha256': sha(OUT/(name+'.png'))}
    im, box = clean_crop(HERE/'masters/divider_r2_color2.png')
    # Preserve the accepted diamond-and-two-rails layout, with compact vertical scale.
    im = im.resize((508,28), LANCZOS)
    final = Image.new('RGBA',(512,32))
    final.paste(im,(2,2))
    final.save(OUT/'divider.png')
    metrics['divider'] = {'master':'masters/divider_r2_color2.png', 'crop_xyxy':box,
        'master_sha256':sha(HERE/'masters/divider_r2_color2.png'), 'size': [512,32],
        'margins_ltrb_px':None, 'border_hsv':stats(final),
        'sha256':sha(OUT/'divider.png'),
        'horizontal_regions_x_width':[[0,16],[16,216],[232,48],[280,216],[496,16]]}
    (HERE/'processing_metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
    return metrics

def font(size):
    return ImageFont.truetype('C:/Windows/Fonts/arial.ttf',size)

def validate(metrics):
    for name,m in metrics.items():
        im = Image.open(OUT/(name+'.png'))
        a = np.array(im).astype(int)
        assert im.mode == 'RGBA' and list(im.size) == list(m['size'])
        green = (a[:,:,1] > np.maximum(a[:,:,0],a[:,:,2])+20) & (a[:,:,3] > 16)
        assert not green.any(), name+' green rim'
        if name != 'tab_idle':
            assert .75 <= m['border_hsv']['saturation'] <= .85, name+' saturation'
        if name in SPECS:
            l,t,r,b = m['margins_ltrb_px']
            assert a[t:im.height-b,l:im.width-r,3].min() == 255
    active = metrics['tab_active']['border_hsv']
    idle = metrics['tab_idle']['border_hsv']
    reductions = {k:1-idle[k]/active[k] for k in ('saturation','value')}
    assert all(.30 <= v <= .40 for v in reductions.values())
    for name in ('tab_active','tab_idle'):
        l,t,r,b = metrics[name]['margins_ltrb_px']
        assert t+b <= 10
        preview = nine(Image.open(OUT/(name+'.png')),(160,25),(l,t,r,b))
        assert preview.size == (160,25)
    report = {'passed':True, 'png_count':6, 'green_rim_pixels':0,
              'opaque_frame_centers':True, 'non_idle_saturation_range':[.75,.85],
              'idle_reductions':reductions, 'tab_vertical_margins_total_px':10,
              'slot_clear_center_px':[36,36]}
    (HERE/'image_validation.json').write_text(json.dumps(report,indent=2)+'\n')

def sheets(metrics):
    # Each half contains a native 900x620 panel. Never thumbnail the stretch samples.
    canvas = Image.new('RGB',(2520,1130),(19,17,16))
    d = ImageDraw.Draw(canvas)
    ref = Image.open(HERE/'cover_chrome_reference.png').convert('RGB')
    ref.thumbnail((290,160), LANCZOS)
    for k,bg in enumerate(((18,16,14),(108,103,95))):
        x = k*1260
        d.rectangle((x,0,x+1259,1129),fill=bg)
        d.text((x+20,16),'T52a ROUND 2 / '+('DARK' if k==0 else 'MID')+' / native 1:1 pixels',font=font(23),fill='#f2dbb4')
        canvas.paste(ref,(x+20,83))
        d.text((x+20,245),'Cover crown reference',font=font(18),fill='#f2dbb4')
        d.text((x+330,53),'PANEL 900 x 620 / margins 16 px',font=font(18),fill='#f2dbb4')
        panel = nine(Image.open(OUT/'panel.png'),(900,620),(16,)*4)
        canvas.paste(panel,(x+330,83),panel)
        # Small sample controls all at their real display size, on the backdrop.
        d.text((x+330,728),'CARD 500 x 90 / margins 9 px',font=font(18),fill='#f2dbb4')
        card = nine(Image.open(OUT/'card.png'),(500,90),(9,)*4)
        canvas.paste(card,(x+330,758),card)
        for n,name in enumerate(('tab_active','tab_idle')):
            xx=x+330+n*210
            d.text((xx,870),name+' / 160 x 32',font=font(16),fill='#f2dbb4')
            tab=Image.open(OUT/(name+'.png'))
            canvas.paste(tab,(xx,897),tab)
            d.text((xx,945),'160 x 25 / T+B = 10 px',font=font(16),fill='#f2dbb4')
            small=nine(tab,(160,25),(5,)*4)
            canvas.paste(small,(xx,972),small)
        d.text((x+875,728),'SLOT 48 x 48 / 6 px',font=font(17),fill='#f2dbb4')
        slot=Image.open(OUT/'slot.png')
        canvas.paste(slot,(x+875,758),slot)
        d.text((x+875,825),'36 x 36 clear center',font=font(16),fill='#f2dbb4')
        d.text((x+330,1020),'DIVIDER 512 x 32 / fixed center and endcaps',font=font(18),fill='#f2dbb4')
        div=Image.open(OUT/'divider.png')
        canvas.paste(div,(x+330,1052),div)
        d.text((x+20,315),'Shipped PNGs:',font=font(18),fill='#f2dbb4')
        for idx,(name,m) in enumerate(metrics.items()):
            s=m['border_hsv']
            d.text((x+20,345+idx*60),f"{name}: {m['size'][0]} x {m['size'][1]}\nH {s['hue_degrees']:.0f} / S {s['saturation']:.2f} / V {s['value']:.2f}",font=font(16),fill='#f2dbb4')
    canvas.save(HERE/'contact_sheet_v2.png')
    # Separate halves make 1:1 inspection easier in viewers that shrink wide images.
    for k,label in enumerate(('dark','mid')):
        canvas.crop((k*1260,0,(k+1)*1260,1130)).save(HERE/f'stretch_preview_{label}.png')

if __name__ == '__main__':
    result=build()
    validate(result)
    sheets(result)
    print(json.dumps({n:m['border_hsv'] for n,m in result.items()},indent=2))
