import {test} from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import {normalizeMatricula,identityEmail} from '../src/identity.js';
const source=fs.readFileSync(new URL('../api/identity.js',import.meta.url),'utf8').replace(/^import .*;\s*$/gm,'').replace('export default async function','async function');
async function signup({roster=true,existing=false,password='Example!123',matricula='00123',error=null,name='Pessoa Teste',department='RH'}={}){
 let created,code,result;
 const db={from(table){const q={select(){return q},eq(){return q},async maybeSingle(){return {data:table==='br_employees'?(roster?{matricula}:null):(existing?{id:'old'}:null)}}};return q},auth:{admin:{async createUser(data){created=data;return {error,data:{user:{id:'new'}}}}}}};
 const context=vm.createContext({normalizeMatricula,identityEmail,createClient:()=>db,process:{env:{VITE_SUPABASE_URL:'mock',VITE_SUPABASE_PUBLISHABLE_KEY:'mock',SUPABASE_SERVICE_ROLE_KEY:'mock'}},console:{error(){}}});
 vm.runInContext(source,context);
 const res={setHeader(){},status(n){code=n;return res},json(data){result=data;return res},end(){return res}};
 await context.handler({method:'POST',body:{action:'signup',matricula,password,contact_email:'',name,department},headers:{}},res);
 return {created,code,result};
}
test('authorized registration creates confirmed synthetic identity without public signup',async()=>{const r=await signup();assert.equal(r.code,201);assert.equal(r.created.email,'00123@login.braveiros.example.com');assert.equal(r.created.email_confirm,true);assert.equal(r.created.user_metadata.matricula,'00123');});
test('registration without prior roster creates pending identity',async()=>{const r=await signup({roster:false});assert.equal(r.code,201);assert.equal(r.created.user_metadata.name,'Pessoa Teste');});
test('duplicate registration never creates account',async()=>{const r=await signup({existing:true});assert.equal(r.code,400);assert.equal(r.created,undefined);});
test('short password never creates account',async()=>{const r=await signup({password:'123'});assert.equal(r.code,400);assert.equal(r.created,undefined);});

test('missing name is rejected',async()=>{const r=await signup({name:''});assert.equal(r.code,400);assert.equal(r.created,undefined);});
test('missing department is rejected',async()=>{const r=await signup({department:''});assert.equal(r.code,400);assert.equal(r.created,undefined);});
