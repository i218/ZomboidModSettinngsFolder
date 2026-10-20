"""Render a code-native cover to editable SVG and metadata-free RGB PNG.

Needs Pillow and the standard Windows Segoe UI fonts; no network or AI assets.
"""
from pathlib import Path
from html import escape
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SCALE = 3
image = Image.new("RGB", (512 * SCALE, 512 * SCALE), "#131c1d")
draw = ImageDraw.Draw(image)
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">']


def rect(box, fill, radius=0):
    draw.rounded_rectangle(tuple(int(v*SCALE) for v in box), radius*SCALE, fill=fill)
    x,y,x2,y2=box
    svg.append(f'<rect x="{x}" y="{y}" width="{x2-x}" height="{y2-y}" rx="{radius}" fill="{fill}"/>')


def path(points, fill):
    draw.polygon([(int(x*SCALE),int(y*SCALE)) for x,y in points], fill=fill)
    svg.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in points)+f'" fill="{fill}"/>')


def text(x,y,value,size,fill,bold=False):
    fontfile=Path(os.environ.get('WINDIR',os.environ.get('SystemRoot',''))) / 'Fonts' / ('segoeuib.ttf' if bold else 'segoeui.ttf')
    font=ImageFont.truetype(str(fontfile),size*SCALE)
    draw.text((x*SCALE,y*SCALE),value,font=font,fill=fill,anchor='lt')
    svg.append(f'<text x="{x}" y="{y}" dominant-baseline="text-before-edge" font-family="Segoe UI, sans-serif" font-size="{size}" font-weight="{700 if bold else 400}" fill="{fill}">{escape(value)}</text>')


rect((0,0,512,512),'#131c1d')
rect((26,28,30,132),'#e9b85e',2)
text(46,30,'MOD SETTINGS',31,'#dce7e1',True)
text(42,68,'FOLDERS',64,'#ffffff',True)
text(46,145,'A place for every setting.',19,'#a5b7b0')
# Folder hierarchy: two cards linked to a parent, drawn as a clear symbolic icon.
rect((63,216,67,371),'#51645d',2)
rect((65,368,134,372),'#51645d',2)
rect((65,269,134,273),'#51645d',2)
path([(115,226),(115,210),(168,210),(181,226),(358,226),(358,289),(115,289)],'#b48032')
rect((115,233,368,299),'#ebbe68',8)
rect((138,253,153,268),'#3c4638',3)
rect((166,253,324,259),'#725c32',3)
rect((166,267,284,273),'#967b45',3)
path([(115,326),(115,310),(168,310),(181,326),(358,326),(358,389),(115,389)],'#50766b')
rect((115,333,368,399),'#8db9a6',8)
rect((138,353,153,368),'#28413b',3)
rect((166,353,324,359),'#486c60',3)
rect((166,367,284,373),'#608778',3)
rect((337,274,453,355),'#22322f',10)
rect((356,294,372,310),'#e9b85e',3)
path([(359,301),(362,305),(369,297),(372,300),(362,310),(356,304)],'#22322f')
rect((385,297,432,302),'#b7cbc0',2)
rect((356,321,372,337),'#8db9a6',3)
rect((385,324,432,329),'#b7cbc0',2)
rect((40,440,177,478),'#263a33',8)
text(57,450,'BUILD 42',17,'#d2e1d8',True)
text(205,450,'CLIENT SIDE',16,'#a5b7b0',True)
svg.append('</svg>')
(ROOT/'preview.svg').write_text('\n'.join(svg)+'\n',encoding='utf8')
image.resize((512,512),Image.Resampling.LANCZOS).save(ROOT/'preview.png',optimize=True)
print('Rendered preview.svg and preview.png (512 x 512, RGB).')
