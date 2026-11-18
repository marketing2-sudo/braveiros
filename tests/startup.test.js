import {test} from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import * as modules from '../src/modules.js';
import * as identity from '../src/identity.js';
const code=fs.readFileSync(new URL('../src/main.js',import.meta.url),'utf8').replace(/^import .*;\s*$/gm,'').replace('import.meta.env','envMock');
async function run({seen=false,profile=null,rosterError=false,storageBlocked=false}={}){
 const app={innerHTML:'',addEventListener(){}};let callback;const timers=[];const values=new Map(seen?[['braveiros_onboarding_seen','true']]:[]);
 const db={auth:{onAuthStateChange(fn){callback=fn}},rpc:async()=>({data:profile?.role}),from(table){let single=false;const q={select(){return q},eq(){return q},order(){return q},limit(){return q},maybeSingle(){single=true;return q},then(resolve){resolve(table==='br_employees'&&rosterError?{error:{message:'Missing table'}}:{data:single?profile:[]})}};return q}};
 const context=vm.createContext({...modules,...identity,envMock:{VITE_SUPABASE_URL:'mock',VITE_SUPABASE_PUBLISHABLE_KEY:'mock'},createClient:()=>db,document:{querySelector:s=>s==='#app'?app:null,addEventListener(){},documentElement:{classList:{add(){}}}},window:{addEventListener(){},scrollTo(){},location:{}},navigator:{},localStorage:{getItem(k){if(storageBlocked)throw Error('blocked');return values.get(k)},setItem(k,v){if(storageBlocked)throw Error('blocked');values.set(k,v)}},console:{info(){},warn(){},error(){}},setTimeout(fn,ms){if(ms<15000)timers.push(fn);return 1},clearTimeout(){},setInterval(){},matchMedia:()=>({matches:false})});
 vm.runInContext(code,context);assert.match(app.innerHTML,/splash-screen/);
 async function event(e,s){callback(e,s);for(let i=0;i<10;i++){while(timers.length)timers.shift()();await new Promise(r=>setImmediate(r))}await vm.runInContext('authQueue',context)}
 return {app,event,context};
}
test('first visit: actual entry script renders onboarding, then independent signup',async()=>{const x=await run();await x.event('INITIAL_SESSION',null);assert.match(x.app.innerHTML,/onboarding-stage/);await vm.runInContext("action('onboarding-next');action('onboarding-next');action('onboarding-finish')",x.context);assert.match(x.app.innerHTML,/data-signup="true"/);assert.doesNotMatch(x.app.innerHTML,/onboarding-stage/)});
test('returning visitor: login only',async()=>{const x=await run({seen:true});await x.event('INITIAL_SESSION',null);assert.match(x.app.innerHTML,/data-signup="false"/)});
test('active session: directly enters portal',async()=>{const x=await run({profile:{name:'Teste',active:true,role:'employee'}});await x.event('INITIAL_SESSION',{user:{id:'u'}});assert.match(x.app.innerHTML,/class="shell"/)});
test('pending session: approval screen',async()=>{const x=await run({profile:{name:'Teste',active:false,role:'employee'}});await x.event('INITIAL_SESSION',{user:{id:'u'}});assert.match(x.app.innerHTML,/Aguardando liberação/)});
test('missing roster does not block super admin portal',async()=>{const x=await run({profile:{name:'Teste',active:true,role:'super_admin'},rosterError:true});await x.event('INITIAL_SESSION',{user:{id:'u'}});assert.match(x.app.innerHTML,/class="shell"/);await vm.runInContext("go('admin')",x.context);assert.match(x.app.innerHTML,/Missing table/)});
test('blocked local storage does not break entry',async()=>{const x=await run({storageBlocked:true});await x.event('INITIAL_SESSION',null);assert.match(x.app.innerHTML,/onboarding-stage/)});
