#!/usr/bin/env python3
"""Picture to 3D model through Microsoft's free TRELLIS.2 Space (microsoft/TRELLIS.2: ZeroGPU, MIT licence).

    python3 skills/image-to-3d/run_trellis.py picture-rgba.png model.glb [--seed 1] [--res 1024]
                                              [--faces 200000] [--texture 2048]

Run it through the brain's AI job (.github/workflows/ai-job.yml), which has the HF_TOKEN secret, a free
Hugging Face account's read token, in the environment: each call asks the Space for 120 s of GPU, more than
anonymous quota allows. The skill's SKILL.md gives the job's code. Free: it runs on Hugging Face's GPUs.

Give it an RGBA picture with the background already cut out (cut_background.py): the Space's own background
removal calls another ZeroGPU Space and was often out of quota. The three calls share one session:
/preprocess_image (crops to the alpha), /image_to_3d (seed and resolution) and /extract_glb (faces and
texture). If the Space changes, Client('microsoft/TRELLIS.2').view_api() lists its endpoints and parameters.
Needs: pip install gradio_client
"""
import argparse
import os
import shutil
import time

from gradio_client import Client, handle_file


def main():
    ap = argparse.ArgumentParser(description='Picture to 3D model (GLB) through the free TRELLIS.2 Space.')
    ap.add_argument('src', help='an RGBA picture with its background cut out')
    ap.add_argument('out', help='the GLB to write')
    ap.add_argument('--seed', type=int, default=1, help='another seed gives another guess at the same picture; 1')
    ap.add_argument('--res', default='1024', help="the Space's resolution choice, as text: '512', '1024' or '1536'; 1024")
    ap.add_argument('--faces', type=int, default=200000, help='the GLB is simplified to about this many faces; 200,000')
    ap.add_argument('--texture', type=int, default=2048, help="the texture's size in pixels; 2048")
    ap.add_argument('--space', default='microsoft/TRELLIS.2', help='the Space to call')
    a = ap.parse_args()

    tok = os.environ.get('HF_TOKEN') or None
    c = Client(a.space, token=tok) if tok else Client(a.space)
    print('signed in with HF_TOKEN' if tok else 'anonymous: HF_TOKEN is not set, so the GPU quota will likely run out',
          flush=True)
    t0 = time.time()
    pre = c.predict(handle_file(a.src), api_name='/preprocess_image')
    print('preprocessed', round(time.time() - t0), 's', flush=True)
    c.predict(handle_file(pre), a.seed, a.res, api_name='/image_to_3d')
    print('generated', round(time.time() - t0), 's', flush=True)
    glb = c.predict(a.faces, a.texture, api_name='/extract_glb')
    if isinstance(glb, (list, tuple)):
        glb = glb[0]
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    shutil.copy(glb, a.out)
    print('glb', a.out, os.path.getsize(a.out) // 1024, 'KB', round(time.time() - t0), 's', flush=True)


if __name__ == '__main__':
    main()
