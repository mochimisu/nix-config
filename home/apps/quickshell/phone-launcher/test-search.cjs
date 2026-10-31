const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(__dirname + '/Search.js', 'utf8').replace('.pragma library', ''), context);
const apps = [
  {name: 'A helper', keywords: ['steam']}, {name: 'Steam Link'},
  {name: 'Steam', id: 'steam'}, {name: 'Steam Tools'},
  {name: 'Super Terminal'}, {name: 'Hidden Steam', noDisplay: true},
  {name: 'My Steam Controller'}, {name: 'Stellar Team'}
];
const names = q => Array.from(context.rank(apps, q), a => a.name);
assert.equal(names('steam')[0], 'Steam');
assert.equal(names('  STEAM  ')[0], 'Steam');
assert.ok(names('steam').indexOf('Steam Link') < names('steam').indexOf('A helper'));
assert.ok(names('steam').indexOf('My Steam Controller') < names('steam').indexOf('A helper'));
assert.equal(names('stm')[0], 'Steam');
assert.equal(names('steam tools')[0], 'Steam Tools');
assert.equal(context.rank([{name:'Café-Tools'}, {name:'Cafe Tools Helper'}], 'cafe tools')[0].name, 'Café-Tools');
assert.ok(!names('').includes('Hidden Steam'));
assert.deepEqual(names('not-an-app-zzzz'), []);
console.log('Search ranking tests passed');

assert.equal(context.detailApp(context.rank(apps, 'sTeAm'), 'sTeAm', 0).id, 'steam');
assert.equal(context.detailApp(context.rank(apps, 'steam'), 'steam', 1), null);
assert.equal(context.detailApp(context.rank(apps, 'not-an-app-zzzz'), 'not-an-app-zzzz', -1), null);
assert.equal(context.detailApp([{name:'Only app'}], 'only', 0).name, 'Only app');
assert.equal(context.detailApp([{name:'Only app'}], '', 0), null);
assert.equal(context.detailApp(context.rank(apps, 'ste'), 'ste', 0), null);
console.log('Detail selection tests passed');
