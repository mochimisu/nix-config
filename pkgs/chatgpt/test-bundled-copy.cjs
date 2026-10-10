const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const prepare = require(process.argv[2] || './prepare-bundled-copy.cjs');

async function fixture(t) {
  const base = await fs.mkdtemp(path.join(os.tmpdir(), 'chatgpt-bundle-test-'));
  t.after(async () => {
    async function unlockDirectories(target) {
      const stat = await fs.lstat(target);
      if (!stat.isDirectory() || stat.isSymbolicLink()) return;
      await fs.chmod(target, (stat.mode & 0o7777) | 0o200);
      for (const child of await fs.readdir(target)) await unlockDirectories(path.join(target, child));
    }
    await unlockDirectories(base);
    await fs.rm(base, { recursive: true, force: true });
  });
  const source = path.join(base, 'source');
  await fs.mkdir(path.join(source, '.codex-plugin'), { recursive: true });
  await fs.mkdir(path.join(source, 'skills/computer-use'), { recursive: true });
  for (const [relative, mode] of [
    ['.codex-plugin/plugin.json', 0o444], ['skills/computer-use/SKILL.md', 0o444],
    ['extension-host', 0o555], ['other.json', 0o444],
  ]) {
    await fs.writeFile(path.join(source, relative), 'original');
    await fs.chmod(path.join(source, relative), mode);
  }
  const copy = path.join(base, 'copy');
  await fs.cp(source, copy, { recursive: true });
  const directories = ['', '.codex-plugin', 'skills', 'skills/computer-use'];
  for (const relative of directories) await fs.chmod(path.join(copy, relative), 0o555);
  return { base, source, copy, directories };
}

async function mode(file) { return (await fs.stat(file)).mode & 0o7777; }

test('visualize: rewrite succeeds; executable and unrelated file modes stay unchanged', async t => {
  const { source, copy, directories } = await fixture(t);
  const manifest = path.join(copy, '.codex-plugin/plugin.json');
  await assert.rejects(fs.writeFile(manifest, 'changed'), { code: 'EACCES' });
  await prepare({ fs, path, pluginRoot: copy, pluginName: 'visualize' });
  await fs.writeFile(manifest, 'changed');
  assert.equal(await mode(manifest), 0o644);
  for (const dir of directories) assert.equal(await mode(path.join(copy, dir)), 0o755);
  for (const [file, expected] of [['extension-host', 0o555], ['other.json', 0o444],
                                ['skills/computer-use/SKILL.md', 0o444]]) {
    assert.equal(await mode(path.join(copy, file)), expected);
  }
  assert.equal(await mode(path.join(source, '.codex-plugin/plugin.json')), 0o444);
  assert.equal(await fs.readFile(path.join(source, '.codex-plugin/plugin.json'), 'utf8'), 'original');
  await fs.rm(copy, { recursive: true });
});

for (const enabled of [false, true]) test(`computer-use audio=${enabled}`, async t => {
  const { copy } = await fixture(t);
  await prepare({ fs, path, pluginRoot: copy, pluginName: 'computer-use', computerUseAudioEnabled: enabled });
  for (const file of ['.codex-plugin/plugin.json', 'skills/computer-use/SKILL.md']) {
    assert.equal(await mode(path.join(copy, file)), enabled ? 0o644 : 0o444);
  }
  assert.equal(await mode(path.join(copy, 'extension-host')), 0o555);
});

test('other plugins only gain writable directories', async t => {
  const { copy } = await fixture(t);
  await prepare({ fs, path, pluginRoot: copy, pluginName: 'chrome' });
  assert.equal(await mode(path.join(copy, '.codex-plugin/plugin.json')), 0o444);
  assert.equal(await mode(path.join(copy, 'extension-host')), 0o555);
});

test('symlinks cannot expose an outside target to chmod', async t => {
  const { base, copy } = await fixture(t);
  const outside = path.join(base, 'outside');
  await fs.mkdir(outside, { mode: 0o555 });
  await fs.chmod(copy, 0o755);
  await fs.symlink(outside, path.join(copy, 'outside-link'));
  await assert.rejects(prepare({ fs, path, pluginRoot: copy, pluginName: 'visualize' }), /symlinked/);
  assert.equal(await mode(outside), 0o555);
});

test('an executable manifest is rejected without changing its mode', async t => {
  const { copy } = await fixture(t);
  const manifest = path.join(copy, '.codex-plugin/plugin.json');
  await fs.chmod(manifest, 0o555);
  await assert.rejects(prepare({ fs, path, pluginRoot: copy, pluginName: 'visualize' }), /executable/);
  assert.equal(await mode(manifest), 0o555);
});

const copyExecutor = prepare.copyExecutorPlugin;

async function executorFixture(t) {
  const base = await fs.mkdtemp(path.join(os.tmpdir(), 'chatgpt-executor-test-'));
  async function unlock(target) {
    const info = await fs.lstat(target);
    if (info.isSymbolicLink() || !info.isDirectory()) return;
    await fs.chmod(target, (info.mode & 0o7777) | 0o200);
    for (const child of await fs.readdir(target)) await unlock(path.join(target, child));
  }
  t.after(async () => { await unlock(base); await fs.rm(base, {recursive:true, force:true}); });
  const source = path.join(base, 'source');
  const cache = path.join(base, 'executor-plugins', 'codex-app-tools');
  await fs.mkdir(path.join(source, 'scripts'), {recursive:true});
  for (const [file, content, permissions] of [
    ['.mcp.json', '{"original":true}', 0o444],
    ['scripts/launch.cmd', 'launcher', 0o555],
    ['other.json', 'leave read-only', 0o440],
  ]) {
    await fs.writeFile(path.join(source,file), content);
    await fs.chmod(path.join(source,file),permissions);
  }
  await fs.chmod(path.join(source,'scripts'), 0o550);
  await fs.chmod(source,0o555);
  return {base, source, cache, options:{fs,path,sourceRoot:source,pluginRoot:cache}};
}

async function verifyExecutor(fixture, expected) {
  const {source,cache} = fixture;
  await fs.writeFile(path.join(cache,'.mcp.json'),expected,'utf8');
  assert.equal(await fs.readFile(path.join(cache,'.mcp.json'),'utf8'),expected);
  for (const [file,sourceMode,cacheMode] of [
    ['',0o555,0o755],['scripts',0o550,0o750],['.mcp.json',0o444,0o644],
    ['scripts/launch.cmd',0o555,0o555],['other.json',0o440,0o440],
  ]) {
    assert.equal(await mode(path.join(source,file)),sourceMode,file+' source mode');
    assert.equal(await mode(path.join(cache,file)),cacheMode,file+' cache mode');
    assert.equal((await fs.lstat(path.join(cache,file))).uid,process.getuid());
  }
  assert.equal(await fs.readFile(path.join(source,'.mcp.json'),'utf8'),'{"original":true}');
}

test('executor fresh cache: copy then manifest write; source and unrelated modes unchanged', async t => {
  const f = await executorFixture(t);
  await copyExecutor(f.options);
  await verifyExecutor(f,'first startup');
});

test('executor existing read-only cache and repeated starts', async t => {
  const f = await executorFixture(t);
  await fs.cp(f.source,f.cache,{recursive:true});
  assert.equal(await mode(f.cache),0o555);
  assert.equal(await mode(path.join(f.cache,'.mcp.json')),0o444);
  for (let attempt=1;attempt<=3;attempt++) {
    await copyExecutor(f.options);
    await verifyExecutor(f,'startup '+attempt);
  }
});

for (const location of ['root','ancestor','nested','manifest']) test(`executor rejects destination symlink: ${location}`,async t=>{
  const f=await executorFixture(t);
  const outside=path.join(f.base,'outside');
  await fs.mkdir(outside);
  const externalFile=path.join(outside,'outside.json');
  await fs.writeFile(externalFile,'do not change');await fs.chmod(externalFile,0o444);
  if(location==='ancestor') await fs.symlink(outside,path.dirname(f.cache));
  else {
    await fs.mkdir(path.dirname(f.cache),{recursive:true});
    if(location==='root') await fs.symlink(outside,f.cache);
    else {
      await fs.mkdir(f.cache);
      await fs.symlink(location==='manifest'?externalFile:outside,path.join(f.cache,location==='manifest'?'.mcp.json':'scripts'));
    }
  }
  await fs.chmod(outside,0o555);
  await assert.rejects(copyExecutor(f.options),/symlinked/);
  assert.equal(await mode(outside),0o555);
  assert.equal(await mode(externalFile),0o444);
  assert.equal(await fs.readFile(externalFile,'utf8'),'do not change');
});

for(const location of ['root','ancestor','nested','manifest']) test(`executor rejects source symlink: ${location}`,async t=>{
  const f=await executorFixture(t);
  if(location==='root') {
    const alias=path.join(f.base,'source-alias');await fs.symlink(f.source,alias);f.options.sourceRoot=alias;
  }else if(location==='ancestor') {
    const alias=path.join(f.base,'base-alias');await fs.symlink(f.base,alias);f.options.sourceRoot=path.join(alias,'source');
  }else {
    await fs.chmod(f.source,0o755);
    const externalFile=path.join(f.base,'outside.json');await fs.writeFile(externalFile,'outside');await fs.chmod(externalFile,0o444);
    if(location==='manifest')await fs.unlink(path.join(f.source,'.mcp.json'));
    await fs.symlink(externalFile,path.join(f.source,location==='manifest'?'.mcp.json':'outside-link'));
  }
  await assert.rejects(copyExecutor(f.options),/symlinked/);
  await assert.rejects(fs.lstat(f.cache),{code:'ENOENT'});
});

test('executor refuses overlapping roots before changing source modes',async t=>{
  const f=await executorFixture(t);
  for(const destination of [f.source,path.join(f.source,'nested'),f.base,path.parse(f.base).root]){
    await assert.rejects(copyExecutor({...f.options,pluginRoot:destination}),/overlapping|unbounded/);
    assert.equal(await mode(f.source),0o555);
  }
});

test('executor rejects executable source manifest before any cache writes',async t=>{
  const f=await executorFixture(t);
  await fs.chmod(path.join(f.source,'.mcp.json'),0o555);
  await assert.rejects(copyExecutor(f.options),/non-executable/);
  await assert.rejects(fs.lstat(f.cache),{code:'ENOENT'});
});

test('executor rejects unowned destination without chmod (metadata simulation)',async t=>{
  const f=await executorFixture(t);
  await fs.cp(f.source,f.cache,{recursive:true});
  const fake=Object.create(fs);
  fake.lstat=async target=>{
    const info=await fs.lstat(target);
    if(target===f.cache)Object.defineProperty(info,'uid',{value:process.getuid()+1});
    return info;
  };
  await assert.rejects(copyExecutor({...f.options,fs:fake}),/unowned/);
  assert.equal(await mode(f.cache),0o555);
  assert.equal(await mode(path.join(f.cache,'.mcp.json')),0o444);
});

test('executor refuses a substituted final symlink before descriptor chmod',async t=>{
  const f=await executorFixture(t);
  await fs.cp(f.source,f.cache,{recursive:true});
  const outside=path.join(f.base,'outside');await fs.mkdir(outside);await fs.chmod(outside,0o555);
  const fake=Object.create(fs);let swapped=false;
  fake.open=async(target,flags)=>{
    if(target===f.cache && !swapped){swapped=true;await fs.rename(f.cache,f.cache+'.old');await fs.symlink(outside,f.cache);}
    return fs.open(target,flags);
  };
  await assert.rejects(copyExecutor({...f.options,fs:fake}),{code:'ELOOP'});
  assert.equal(await mode(outside),0o555);
});
