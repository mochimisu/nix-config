"""Check synthetic headless-renderer screenshots; requires Pillow."""
import argparse
from pathlib import Path
from PIL import Image, ImageChops
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('directory',type=Path)
parser.add_argument('--scale',type=int,choices=[1,2],default=1)
args=parser.parse_args()
for name in ['dnd-hidden','empty','timeout-empty','burst-empty']:
    image=Image.open(args.directory/(name+'.png')).convert('RGB')
    background=Image.new('RGB',image.size,image.getpixel((0,0)))
    assert ImageChops.difference(image,background).getbbox() is None, name+' contains residue'
# Interior of the surviving fixture card: departing snapshots must not leak
# through its translucent background while the stack collapses.
region=tuple(value*args.scale for value in (420,42,710,78))
a=Image.open(args.directory/'stack-collapse-early.png').convert('RGB').crop(region)
b=Image.open(args.directory/'stack-collapse-settled.png').convert('RGB').crop(region)
assert ImageChops.difference(a,b).getbbox() is None,'Stacked exit altered surviving card pixels'
print('PASS: no DND/exit residue; stacked-exit text remains unchanged')
