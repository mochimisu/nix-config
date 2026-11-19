// Exercise the actual patched upstream methods, without launching a user profile.
const assert = require('node:assert/strict');
const vm = require('node:vm');
const source = require('node:fs').readFileSync(0, 'utf8');
function between(start, end) {
  assert.equal(source.split(start).length, 2, `unique start: ${start}`);
  const tail = source.slice(source.indexOf(start));
  assert.ok(tail.includes(end), `end: ${end}`);
  return tail.slice(0, tail.indexOf(end));
}
const ensure = between('async ensureWindow(e){', 'refreshNativeActiveAppearance(e){');
const present = between('shouldPresentWindow(){', 'updateRendererActivity(){');
const initial = between('let tR=td.deepLinks.isWakeOnlyLaunch()', 'let tE=null,tD=');
const fallback = between('let tW=tR;', 'ep.add((l=');
(async () => {
  assert.ok(!source.includes('codexNixDisableMini'), 'no injected Mini suppression');
  const manager = vm.runInNewContext(`({${ensure},${present}})`);
  let created = 0;
  const window = {isDestroyed: () => false};
  Object.assign(manager, {
    petOpenIntent: false,
    realtimeController: {prepareForWindowCreation() {}},
    createWindow: async () => { created++; return window; },
  });
  assert.equal(await manager.ensureWindow(0), window, 'native overlay allocation preserved');
  assert.equal(created, 1);
  assert.equal(manager.shouldPresentWindow(), false, 'native hidden preference respected');
  manager.petOpenIntent = true;
  assert.equal(manager.shouldPresentWindow(), true, 'native Show pet remains available');
  for (const hidden of [false, true]) {
    for (const background of [false, true]) {
      for (const code of [initial + 'return tR;', fallback + 'return tW;']) {
        const creations = [], reveals = [];
        const window = {once() {}, isDestroyed: () => false};
        const result = await vm.runInNewContext(`(async()=>{${code}})()`, {
          codexNixStartHidden: hidden, B: {isBackgroundLaunch: background, windowsActivation: null},
          td: {deepLinks: {isWakeOnlyLaunch: () => false}}, eL: false,
          eO: {ensureWindow: async options => { creations.push(options.background); return window; }, windowManager: {getPersistenceWindowId: () => "primary"}},
          tp: w => reveals.push(w), th: false, eD: {handleInitialWindowVisible() {}},
          tR: null, tA: null, J: {reach() {}},
        });
        assert.equal(result, window);
        assert.deepEqual(creations, [hidden || background]);
        assert.equal(reveals.length, hidden || background ? 0 : 1);
      }
    }
  }
  // Reopening still uses the original interactive show/restore/focus path.
  assert.ok(source.includes('B.onInteractiveLaunch=()=>{null==tR||tR.isDestroyed()||tp(tR)'));
  assert.ok(source.includes('let r=eO.getPrimaryWindow()??await eW("/");if(null==r)return;tp(r)'));
  console.log('Window controls: actual hidden startup and native overlay methods passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
