// Checks the brain graph's quick way of working out links against the full way, over a repo's
// whole history: builds the replay both ways, straight from git (no saved history file), and
// says whether they're the same, byte for byte. Run it after any change to how the replay is
// built (LinkBook, assemble, readModel). In a brain with 3,850 commits the full way takes about
// three minutes in a cloud session; a new brain, seconds.
//
//   node .obsidian/plugins/brain-graph/test/same-as-full.mjs [main.js] [repo]
//
// Both default to this plugin's main.js and the repo it's in. A cloud clone is shallow, so run
// `git fetch --unshallow origin main` first to check the whole history.
import fs from 'fs';
import { createRequire } from 'module';
const here = new URL('.', import.meta.url).pathname;
const mainPath = process.argv[2] || here + '../main.js';
const repo = process.argv[3] || new URL('../../../../', import.meta.url).pathname.replace(/\/$/, '');
const require = createRequire(import.meta.url);
const obsidian = { Plugin: class {}, ItemView: class {}, Notice: class {}, TFile: class {} };
globalThis.window = globalThis;
const names = ['Git', 'readModel', 'assemble', 'parseLog', 'readBlobs', 'decoder', 'kindOf', 'countsLines', 'countLines', 'extractLinks'];
const api = new Function('require', 'module', 'exports', fs.readFileSync(mainPath, 'utf8') + '\n;return {' + names.join(',') + '};')(
  (m) => (m === 'obsidian' ? obsidian : require(m)), { exports: {} }, {});

const git = await api.Git.open(repo);
const t0 = Date.now();
const quick = await api.readModel(git, null);
const how = quick.how;
delete quick.how;
console.log(`quick way: ${Date.now() - t0} ms, links checked ${how.links === 'quick' ? 'and matched' : 'and did NOT match, so it fell back to the full way'}; ${quick.nodes.length} notes, ${quick.edges.length} links, ${quick.steps.length} steps`);

// The full way: the same commits and facts, every link worked out again after every commit.
const head = (await git.text(['rev-parse', 'HEAD'])).trim();
const order = (await git.text(['rev-list', '--reverse', '--date-order', head])).split('\n').filter(Boolean);
const commits = api.parseLog(api.decoder.decode(await git.run(['-c', 'core.quotepath=false', 'log', '--reverse', '--date-order', '--diff-merges=first-parent', '-M', '--raw', '--numstat', '-z', '--no-abbrev', '--format=%x1e%H%x1f%P%x1f%ct%x1f%an%x1f%s', head])));
if (commits.map((c) => c.sha).join() !== order.join()) console.log('NOTE: git log and rev-list gave the commits in different orders');
const need = new Map();
for (const c of commits) for (const e of c.raw) {
  if (e.status === 'D' || e.mode === '160000') continue;
  const k = api.kindOf(e.path);
  if (api.countsLines(k)) need.set(e.sha, need.get(e.sha) || k === 'note');
}
const blobs = await api.readBlobs(git, [...need.keys()]);
const facts = new Map();
for (const [sha, note] of need) { const b = blobs.get(sha); if (b) facts.set(sha, [api.countLines(b), note ? api.extractLinks(api.decoder.decode(b)) : null]); }
const t1 = Date.now();
const full = api.assemble(head, commits, facts, null, true);
console.log(`full way: ${Date.now() - t1} ms`);
const a = JSON.stringify(quick), b = JSON.stringify(full);
if (a === b) console.log('SAME: the quick way gives exactly the full way\'s replay.');
else {
  console.log('DIFFERENT: the quick way and the full way disagree in ' + Object.keys(full).filter((k) => JSON.stringify(full[k]) !== JSON.stringify(quick[k])).join(', ') + '.');
  process.exitCode = 1;
}
