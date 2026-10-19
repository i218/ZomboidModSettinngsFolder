"""Render the small, text-free in-game icon and reuse the cover as its poster."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
COMMON = ROOT.parent / "Contents/mods/ModSettingsFolders/common"
SCALE = 4
image = Image.new("RGB", (256*SCALE,256*SCALE), "#131c1d")
draw = ImageDraw.Draw(image)
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">']


def rect(box,fill,radius=0):
    draw.rounded_rectangle(tuple(int(v*SCALE) for v in box),radius*SCALE,fill=fill)
    x,y,x2,y2=box
    svg.append(f'<rect x="{x}" y="{y}" width="{x2-x}" height="{y2-y}" rx="{radius}" fill="{fill}"/>')


def poly(points,fill):
    draw.polygon([(x*SCALE,y*SCALE) for x,y in points],fill=fill)
    svg.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in points)+f'" fill="{fill}"/>')


rect((0,0,256,256),'#131c1d')
rect((20,54,28,194),'#7f9b90',4)
rect((24,82,62,90),'#7f9b90',4)
rect((24,186,62,194),'#7f9b90',4)
poly([(48,63),(48,40),(99,40),(116,59),(226,59),(226,114),(48,114)],'#ae7b31')
rect((48,66,238,126),'#ebbe68',10)
rect((67,87,83,103),'#3d493c',3)
rect((98,91,215,99),'#725c32',4)
poly([(48,159),(48,140),(99,140),(116,159),(226,159),(226,214),(48,214)],'#50766b')
rect((48,166,238,226),'#8db9a6',10)
rect((67,187,83,203),'#28413b',3)
rect((98,191,215,199),'#486c60',4)
svg.append('</svg>')
(ROOT/'icon.svg').write_text('\n'.join(svg)+'\n',encoding='utf8',newline='\n')
COMMON.mkdir(parents=True,exist_ok=True)
image.resize((256,256),Image.Resampling.LANCZOS).save(COMMON/'icon.png',optimize=True)
(COMMON/'poster.png').write_bytes((ROOT/'preview.png').read_bytes())
print('Rendered icon.png (256px) and copied poster.png (512px); authoring SVG stays outside runtime.')
