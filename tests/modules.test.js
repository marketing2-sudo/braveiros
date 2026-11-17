import test from 'node:test';import assert from 'node:assert/strict';import {modules,publicKinds,safeUrl,activeNotice} from '../src/modules.js';
test('unique modules',()=>assert.equal(new Set(modules.map(m=>m[0])).size,16));
test('private modules excluded from publications',()=>assert.ok(['sac','suggestions','ombudsman'].every(k=>!publicKinds.includes(k))));
test('restrict external links to https',()=>{assert.equal(safeUrl('javascript:alert(1)'),'');assert.equal(safeUrl('http://example.com'),'');assert.equal(safeUrl('https://example.com'),'https://example.com/')});
test('published notices visible until expiration in Bahia',()=>{let p={kind:'notice',published:true,extra:{expires:'2026-11-17'}};assert.ok(activeNotice(p,new Date('2026-11-18T01:00:00Z')));assert.ok(!activeNotice(p,new Date('2026-11-18T04:00:00Z')))});
test('unpublished announcements are hidden',()=>assert.ok(!activeNotice({kind:'notice',published:false})));
