"""Find fal models and read their inputs. Free, with no key, from any machine. Standard library only.

    python3 skills/fal/fal_find.py search "image to video" [--limit 10] [--category image-to-video]
    python3 skills/fal/fal_find.py schema fal-ai/flux/schnell     # the model's inputs and outputs, by name
    python3 skills/fal/fal_find.py docs fal-ai/flux/schnell       # fal's own page for the model, as text
    python3 skills/fal/fal_find.py count                          # how many models fal lists today, by kind

search matches keywords, not sentences: turn the ask into a kind of job ("image to video", "remove background",
"text to speech") and search that. Prices need the key: run_fal.py --price reads them, and a model's docs page
often gives them too.
"""
import json
import sys
import urllib.error
import urllib.parse
import urllib.request


def get(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'brain-fal-find'}), timeout=60) as r:
            return r.read().decode()
    except urllib.error.HTTPError as ex:
        sys.exit('fal answered %s for %s: check the endpoint id with search.' % (ex.code, url))
    except urllib.error.URLError as ex:
        sys.exit("fal couldn't be reached (%s). From a session whose network is limited, allow fal.ai and api.fal.ai." % ex.reason)


def search(q, limit=10, category=None):
    p = {'q': q, 'limit': limit}
    if category:
        p['category'] = category
    d = json.loads(get('https://api.fal.ai/v1/models?' + urllib.parse.urlencode(p)))
    models = d.get('models', [])
    for m in models:
        md = m.get('metadata', {})
        print('%-55s %-18s %s' % (m['endpoint_id'], md.get('category', ''), md.get('display_name', '')))
        print('    ' + (md.get('description') or '').strip()[:200])
    if not models:
        print('Nothing found. Search keywords for the kind of job ("image to video"), not a sentence; count lists the categories.')


def schema(eid):
    d = json.loads(get('https://fal.ai/api/openapi/queue/openapi.json?' + urllib.parse.urlencode({'endpoint_id': eid})))
    s = d['components']['schemas']
    for name, body in s.items():
        if not name.endswith(('Input', 'Output')):
            continue
        print('==', name)
        req = set(body.get('required', []))
        for k, v in body.get('properties', {}).items():
            t = v.get('type') or ('enum ' + str(v['enum']) if 'enum' in v else '') or \
                ' | '.join(x.get('type', x.get('$ref', '').split('/')[-1]) for x in v.get('anyOf', []) + v.get('allOf', []))
            extra = []
            if 'enum' in v:
                extra.append('one of ' + ', '.join(map(str, v['enum'])))
            if 'default' in v:
                extra.append('default %r' % (v['default'],))
            print('  %s%s: %s %s' % (k, ' (required)' if k in req else '', t, '; '.join(extra)))
            if v.get('description'):
                print('      ' + v['description'].strip().replace('\n', ' ')[:220])


def count():
    import collections
    kinds, total, cursor = collections.Counter(), 0, None
    while True:
        p = {'limit': 100}
        if cursor:
            p['cursor'] = cursor
        d = json.loads(get('https://api.fal.ai/v1/models?' + urllib.parse.urlencode(p)))
        for m in d.get('models', []):
            total += 1
            kinds[(m.get('metadata') or {}).get('category') or '(none)'] += 1
        cursor = d.get('next_cursor')
        if not d.get('has_more') or not cursor:
            break
    print('%d models' % total)
    for k, n in kinds.most_common():
        print('  %-24s %d' % (k, n))


if __name__ == '__main__':
    a = sys.argv[1:]
    if a[:1] == ['count']:
        count()
    elif len(a) < 2:
        sys.exit(__doc__)
    elif a[0] == 'search':
        lim = int(a[a.index('--limit') + 1]) if '--limit' in a else 10
        cat = a[a.index('--category') + 1] if '--category' in a else None
        search(a[1], lim, cat)
    elif a[0] == 'schema':
        schema(a[1])
    elif a[0] == 'docs':
        print(get('https://fal.ai/models/%s/llms.txt' % a[1]))
    else:
        sys.exit(__doc__)
