"""Run any fal model (image, video, audio, 3D, upscale, cut-out, lip sync...) and save what comes back.

It needs the owner's fal key in the environment as FAL_KEY, which this brain's AI job
(.github/workflows/ai-job.yml) has from the repo's Actions secrets. The key is never printed.

    python skills/fal/run_fal.py jobs.json out --price        # prices and the estimate only: spends nothing
    python skills/fal/run_fal.py jobs.json out --cap 0.50     # send, if the estimate is US$0.50 or under
    python skills/fal/run_fal.py jobs.json out --fetch        # collect runs that outlived an earlier wait
    python skills/fal/run_fal.py --balance                    # what's left on the account, if fal says

jobs.json is a list; each entry is one model run:

    {"name": "shop-banner-1",                          # files are out/<name>.<ext>, notes out/<name>.json
     "endpoint": "fal-ai/flux/schnell",                # fal's endpoint id (fal_find.py search)
     "args": {"prompt": "...", "num_images": 2},       # the model's inputs, as fal_find.py schema names them
     "files": {"image_url": "in/ref.png"},             # input name -> a local file (or a list), uploaded first
     "units": 2}                                       # how many of fal's price units it uses (images, seconds
                                                       # of video, megapixels...). 1 if left out.

Money: before anything is sent, each endpoint's price is read from fal and the batch's estimate (unit price x
units) is printed. Nothing is sent without --cap, and nothing if the estimate is over it or a price couldn't
be read. --cap is the figure the owner said go to for this batch, or a standing limit they have set: the
core's money gate, which SKILL.md spells out. Read the units off the price line (--price): a video priced per
second needs units = its seconds.

All runs are sent at once and waited for together (--wait minutes, 24 by default, inside the AI job's 30).
A run still going at the end isn't lost: its request id is printed and saved in out/<name>.json, and --fetch
collects it without paying again, from that file or from "request_id" added to its entry in jobs.json.

Needs Python 3.8 or later. It installs fal's own client (fal-client) and requests if they aren't there.
"""
import argparse
import concurrent.futures as cf
import json
import os
import subprocess
import sys
import time

MEDIA = ('.png', '.jpg', '.jpeg', '.webp', '.gif', '.mp4', '.webm', '.mov', '.mp3', '.wav', '.ogg', '.m4a',
         '.flac', '.glb', '.gltf', '.fbx', '.obj', '.usdz', '.zip', '.ply', '.splat', '.svg', '.srt', '.vtt', '.txt')


def media_urls(node, found=None):
    """Every file URL in a result, in the order met: known file endings, or a {"url": ...} file object."""
    found = [] if found is None else found
    if isinstance(node, dict):
        u = node.get('url')
        if isinstance(u, str) and u.startswith('http') and u not in found and ('content_type' in node or 'file_name' in node):
            found.append(u)
        for v in node.values():
            media_urls(v, found)
    elif isinstance(node, list):
        for v in node:
            media_urls(v, found)
    elif isinstance(node, str) and node.startswith('http') and node.split('?')[0].lower().endswith(MEDIA) and node not in found:
        found.append(node)
    return found


def headers():
    return {'Authorization': 'Key ' + os.environ['FAL_KEY']}


def prices(endpoints):
    """Each endpoint's price line, in one call (fal answers 429 to several quick single calls), retried."""
    import requests
    eps = sorted(set(endpoints))
    out = {e: None for e in eps}
    for attempt in range(5):
        r = requests.get('https://api.fal.ai/v1/models/pricing', params=[('endpoint_id', e) for e in eps],
                         headers=headers(), timeout=60)
        if r.status_code == 429:
            time.sleep(3 * (attempt + 1))
            continue
        if not r.ok:
            print('prices not read:', r.status_code, r.text[:300])
            break
        for p in r.json().get('prices') or []:
            out[p.get('endpoint_id')] = p
        break
    else:
        print('prices not read: fal kept answering 429')
    return out


def balance():
    import requests
    for url in ('https://api.fal.ai/v1/account/billing?expand=credits', 'https://api.fal.ai/v1/account/billing'):
        r = requests.get(url, headers=headers(), timeout=60)
        print(url.split('/v1/')[1], r.status_code, r.text[:800])
        if r.ok:
            return


def estimate(jobs, pr, cap):
    """Print each run's price line and the batch's estimate. Returns the total and the names with no price."""
    total, unknown = 0.0, []
    for j in jobs:
        p = pr.get(j['endpoint'])
        if not p:
            unknown.append(j['name'])
            print('%-28s %-45s price unknown' % (j['name'], j['endpoint']))
            continue
        units = float(j.get('units', 1))
        cost = float(p['unit_price']) * units
        total += cost
        print('%-28s %-45s %s %s per %s x %g = %.3f' % (j['name'], j['endpoint'], p['unit_price'],
              p.get('currency', 'USD'), p.get('unit', 'unit'), units, cost))
    print('Estimate: US$%.3f for %d runs%s (%s)' % (total, len(jobs), ', plus %d unpriced' % len(unknown) if unknown else '',
          'no cap given' if cap is None else 'cap US$%.2f' % cap), flush=True)
    return total, unknown


def refusal(total, unknown, cap):
    """Why a batch isn't sent, or None if it may be: the money gate, in one place."""
    if cap is None or cap <= 0:
        return ('Not sent: no --cap. Tell the owner the estimate and what it buys, and when they say go, run again '
                'with --cap set to that figure (or to a standing limit they have set).')
    if unknown:
        return "Not sent: fal gave no price for %s, so the batch can't be estimated. Check the endpoint ids." % ', '.join(unknown)
    if total > cap:
        return ('Not sent: the estimate is over the cap. Tell the owner the estimate, and run again with --cap at '
                'the figure they agree.')
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('jobs', nargs='?')
    ap.add_argument('out', nargs='?', default='out')
    ap.add_argument('--wait', type=float, default=24.0, help='minutes to wait for the runs')
    ap.add_argument('--cap', type=float, default=None, help="US$: the owner's go for this batch, or their standing limit; nothing is sent without it or over it")
    ap.add_argument('--price', action='store_true', help='print prices and the estimate, send nothing')
    ap.add_argument('--fetch', action='store_true', help='collect runs sent before, from out/<name>.json or "request_id" in jobs.json')
    ap.add_argument('--balance', action='store_true', help="print the account's credit, if fal shares it")
    a = ap.parse_args()

    if not os.environ.get('FAL_KEY'):
        sys.exit("FAL_KEY is not set. Run this inside the brain's AI job, once the owner has added their fal key "
                 '(SKILL.md, "Set it up"); never paste a key into a chat or a file.')
    if not (a.jobs or a.balance):
        ap.error('give a jobs.json, or --balance')
    try:
        import fal_client
        import requests
    except ImportError:
        subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'fal-client', 'requests'], check=True)
        import fal_client
        import requests

    if a.balance:
        balance()
        if not a.jobs:
            return
    jobs = json.load(open(a.jobs))
    os.makedirs(a.out, exist_ok=True)

    if not a.fetch:
        total, unknown = estimate(jobs, prices(j['endpoint'] for j in jobs), a.cap)
        if a.price:
            return
        no = refusal(total, unknown, a.cap)
        if no:
            sys.exit(no)

    uploaded = {}

    def up(path):
        if path not in uploaded:
            uploaded[path] = fal_client.upload_file(path)
        return uploaded[path]

    def note(job, **more):
        p = os.path.join(a.out, job['name'] + '.json')
        d = json.load(open(p)) if os.path.exists(p) else {'name': job['name'], 'endpoint': job['endpoint']}
        d.update(more)
        json.dump(d, open(p, 'w'), indent=1)
        return d

    sent = []
    for job in jobs:
        try:
            if a.fetch:
                rid = job.get('request_id') or note(job).get('request_id')
                if not rid:
                    print(job['name'], ': no request id in jobs.json or out/, skipped')
                    continue
                note(job, request_id=rid)
            else:
                args = dict(job.get('args') or {})
                for key, val in (job.get('files') or {}).items():
                    args[key] = [up(v) for v in val] if isinstance(val, list) else up(val)
                h = fal_client.submit(job['endpoint'], arguments=args)
                rid = h.request_id
                note(job, request_id=rid, args=args, sent=time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime()))
            print(job['name'], ': collecting,' if a.fetch else ': sent,', job['endpoint'], rid, flush=True)
            sent.append((job, rid))
        except Exception as ex:  # one bad run mustn't stop the rest
            print(job['name'], ': not sent:', repr(ex)[:500], flush=True)
            note(job, error=repr(ex)[:2000])

    end = time.time() + a.wait * 60

    def collect(job, rid):
        t0 = time.time()
        while type(fal_client.status(job['endpoint'], rid)).__name__ != 'Completed':
            if time.time() > end:
                note(job, state='still running when the wait ended: collect it with --fetch')
                return job['name'], 'still running: request id %s' % rid
            time.sleep(6)
        try:
            res = fal_client.result(job['endpoint'], rid)
        except Exception as ex:
            note(job, error=repr(ex)[:2000])
            return job['name'], 'failed: ' + repr(ex)[:300]
        files = []
        for i, u in enumerate(media_urls(res)):
            r = requests.get(u, timeout=600)
            r.raise_for_status()
            ext = os.path.splitext(u.split('?')[0])[1].lower() or '.' + r.headers.get('content-type', 'bin/bin').split('/')[-1].split(';')[0]
            name = job['name'] + ('' if i == 0 else '-%d' % i) + ext
            open(os.path.join(a.out, name), 'wb').write(r.content)
            files.append({'file': name, 'bytes': len(r.content), 'url': u})
        note(job, result=res, files=files, seconds=round(time.time() - t0))
        return job['name'], 'done: ' + (', '.join('%s %.2f MB' % (f['file'], f['bytes'] / 1e6) for f in files) or 'no files, see the json')

    with cf.ThreadPoolExecutor(max_workers=max(1, len(sent))) as pool:
        for fut in cf.as_completed([pool.submit(collect, j, r) for j, r in sent]):
            try:
                print(*fut.result(), sep=': ', flush=True)
            except Exception as ex:
                print('a run failed:', repr(ex)[:500], flush=True)


if __name__ == '__main__':
    main()
