import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import * as modules from '../src/modules.js';
import * as identity from '../src/identity.js';
const js=readFileSync(new URL('../src/main.js',import.meta.url),'utf8').replace(/^import .*;\s*$/gm,'').replace('import.meta.env','envMock');
const css=readFileSync(new URL('../src/social-experience.css',import.meta.url),'utf8');
const sql=readFileSync(new URL('../supabase/v110.sql',import.meta.url),'utf8');
function runVM(){
 const app={innerHTML:'',addEventListener(){}},cls={add(){},remove(){},contains(){return false}},timers=[];
 const context=vm.createContext({URLSearchParams,URL,...modules,...identity,envMock:{},createClient:()=>null,document:{querySelector:s=>s==='#app'?app:null,addEventListener(){},documentElement:{classList:cls}},window:{location:{},addEventListener(){},scrollTo(){}},navigator:{},localStorage:{getItem(){return null},setItem(){}},console:{info(){},warn(){},error(){}},setTimeout(){return 1},clearTimeout(){},setInterval(){},matchMedia:()=>({matches:false})});
 vm.runInContext(js,context);return {app,context};
}
test('social theme has dedicated imported stylesheet',()=>assert.match(readFileSync(new URL('../src/main.js',import.meta.url),'utf8'),/import '\.\/social-experience\.css'/));
test('neutral light and dark themes meet requested direction',()=>{assert.match(css,/--canvas:\s*#ffffff/);assert.match(css,/--canvas:#080808/);assert.match(css,/--ink:#f7f7f7/);assert.match(css,/\.br-story-backdrop/);});
test('posts have functional per-post carousel markup and swipe actions',()=>{const {context}=runVM();const html=vm.runInContext("mediaMarkup({id:'abc',extra:{media:[{path:'a',type:'image/png'},{path:'b',type:'image/png'}]}})",context);assert.match(html,/br-carousel-track/);assert.match(html,/carousel-next:abc/);assert.match(html,/carousel-jump:abc:1/);});
test('story composer requires privileged role',()=>{const {context}=runVM();assert.match(vm.runInContext('storyComposer()',context),/Acesso restrito/);});
test('server policies require staff to insert stories',()=>{assert.match(sql,/br_story_insert[\s\S]*public\.br_staff\(\)/);assert.match(sql,/br_story_delete[\s\S]*public\.br_staff\(\)/);assert.match(sql,/br_story_visible/);assert.doesNotMatch(sql,/DROP TABLE|DELETE FROM auth\.users|TRUNCATE/i);});
test('stories and carousel wiring present',()=>{assert.match(js,/br_stories_feed/);assert.match(js,/story-form/);assert.match(js,/story-open/);assert.match(js,/carousel-prev/);assert.match(js,/\['br-feed','br-stories'\]/);});
