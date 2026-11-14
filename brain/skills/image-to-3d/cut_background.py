#!/usr/bin/env python3
"""Cut a plain studio background out of a picture, ready for an image-to-3D model.

    python3 skills/image-to-3d/cut_background.py picture.png picture-rgba.png [--threshold 34] [--feather 0.8]

A plane fitted to the border pixels models the background, light falling off across it included, so the
picture needs a clear margin of plain background all round. Every pixel whose colour is further than
--threshold from that plane is the object. Small holes are filled and small islands dropped, the edge is
feathered, and the RGBA PNG keeps the picture's size (TRELLIS.2 crops to the alpha itself).

The defaults suit a picture made the way SKILL.md says (plain light grey, soft shadows, about 1024 px):
there, threshold 34 and a feather under 1 px matched a careful hand-made cut by 99.7%. Raise --threshold if
shadow or background haze stays in; lower it if dark-grey parts of the object go. With --keep-inside, only
background that reaches the picture's edge is cut, so grey parts of the object stay, but so do enclosed gaps
you can see through.

It prints the background colour, how plain the border was, and how much of the picture is the object.
Needs: pip install numpy pillow scipy
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage as ndi


def fit_plane(rgb, mask, xx, yy):
    """Per channel, colour = a + b x + c y, fitted to the pixels in mask (x and y run 0 to 1)."""
    X = np.stack([np.ones(int(mask.sum())), xx[mask], yy[mask]], 1)
    coef, *_ = np.linalg.lstsq(X, rgb[mask], rcond=None)
    return coef[0] + coef[1] * xx[..., None] + coef[2] * yy[..., None]


def small_parts(mask, limit, keep_edge):
    """The pieces of mask smaller than limit pixels (optionally not those touching the picture's edge)."""
    lab, n = ndi.label(mask)
    if not n:
        return np.zeros_like(mask)
    small = np.bincount(lab.ravel()) < limit
    small[0] = False
    if keep_edge:
        small[np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))] = False
    return small[lab]


def main():
    ap = argparse.ArgumentParser(description='Cut a plain studio background out of a picture (RGBA out).')
    ap.add_argument('src', help='the picture: one object on a plain background, with a margin all round')
    ap.add_argument('out', help='the RGBA PNG to write')
    ap.add_argument('--threshold', type=float, default=34.0,
                    help='colour distance (RGB 0-255) from the background above which a pixel is the object; 34')
    ap.add_argument('--feather', type=float, default=0.8, help="the edge's blur in pixels; 0.8, 0 for a hard edge")
    ap.add_argument('--border', type=int, default=6, help='how many pixels in from the edge the background is fitted to; 6')
    ap.add_argument('--speck', type=int, default=50, help='fill holes and drop islands smaller than this many pixels; 50')
    ap.add_argument('--keep-inside', action='store_true', help='cut only background that reaches the picture\'s edge')
    a = ap.parse_args()

    rgb = np.asarray(Image.open(a.src).convert('RGB')).astype(float)
    H, W = rgb.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    xx, yy = xx / W, yy / H
    b = max(1, a.border)
    edge = np.zeros((H, W), bool)
    edge[:b] = edge[-b:] = True
    edge[:, :b] = edge[:, -b:] = True

    d = np.linalg.norm(rgb - fit_plane(rgb, edge, xx, yy), axis=2)
    plain = edge & (d < max(3 * np.median(d[edge]), 10.0))  # fit again without any of the object that reaches the edge
    bg = fit_plane(rgb, plain, xx, yy)
    d = np.linalg.norm(rgb - bg, axis=2)

    obj = d > a.threshold
    if a.keep_inside:
        lab, _ = ndi.label(~obj)
        touch = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
        obj = ~np.isin(lab, touch[touch > 0])
    if a.speck > 0:
        obj |= small_parts(~obj, a.speck, keep_edge=True)  # pinholes in the object
        obj &= ~small_parts(obj, a.speck, keep_edge=False)  # dust in the background
    alpha = ndi.gaussian_filter(obj.astype(float), a.feather) if a.feather > 0 else obj.astype(float)

    out = np.dstack([rgb, alpha * 255]).round().clip(0, 255).astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(a.out)
    res = float(np.median(d[edge]))
    print('background', bg[H // 2, W // 2].round().astype(int).tolist(), 'at the centre; border off it by',
          round(res, 1), 'on average (median)', '' if res < 8 else '- the border is not plain: check the cut')
    print('object', f'{obj.mean():.1%}', 'of the picture;', a.out, f'({W}x{H})')
    if obj[edge].mean() > 0.02:
        print('the object reaches the edge of the picture: a margin all round gives a better model')


if __name__ == '__main__':
    main()
