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
const present = between('shouldPresentWindow(){', 'updateRendererBackgroundThrottling(){');
const initial = between('let lt=Ge.deepLinks.isWakeOnlyLaunch()', 'let ut=null,dt=');
const fallback = between('let yt=lt;', 'V.add(Pjt(');
(async () => {
  for (const disabled of [false, true]) {
    const manager = vm.runInNewContext(`({${ensure},${present}})`, {codexNixDisableMini: disabled});
    let created = 0;
    const window = {isDestroyed: () => false};
    Object.assign(manager, {
      petOpenIntent: true,
      realtimeController: {prepareForWindowCreation() {}},
      createWindow: async () => { created++; return window; },
    });
    assert.equal(await manager.ensureWindow(0), disabled ? null : window);
    assert.equal(created, disabled ? 0 : 1);
    assert.equal(manager.shouldPresentWindow(), !disabled);
    manager.presentationVisibility = true;
    assert.equal(manager.shouldPresentWindow(), !disabled);
  }
  // Explicit opens must return before touching the saved preference or creating a window.
  const opening = 'async open(e,{forcePetView:t=!1,focusQuickChat:n=!1,persistPetIntent:r=!0}={}){if(codexNixDisableMini)return;';
  assert.equal(source.split(opening).length, 2);
  for (const hidden of [false, true]) {
    for (const background of [false, true]) {
      for (const code of [initial + 'return lt;', fallback + 'return yt;']) {
        const creations = [], reveals = [];
        const window = {once() {}, isDestroyed: () => false};
        const result = await vm.runInNewContext(`(async()=>{${code}})()`, {
          codexNixStartHidden: hidden, e: {isBackgroundLaunch: background, windowsActivation: null},
          Ge: {deepLinks: {isWakeOnlyLaunch: () => false}}, xe: false,
          K: {ensureWindow: async options => { creations.push(options.background); return window; }},
          Je: w => reveals.push(w), qe: false, ge: {handleInitialWindowVisible() {}},
          lt: null, b: {reach() {}},
        });
        assert.equal(result, window);
        assert.deepEqual(creations, [hidden || background]);
        assert.equal(reveals.length, hidden || background ? 0 : 1);
      }
    }
  }
  // Reopening still uses the original interactive show/restore/focus path.
  assert.ok(source.includes('e.onInteractiveLaunch=()=>{lt!=null&&!lt.isDestroyed()&&Je(lt)'));
  assert.ok(source.includes('let n=K.getPrimaryWindow()??await Ce(`/`);if(n==null)return;Je(n)'));
  console.log('Window controls: actual startup/fallback and overlay methods passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
