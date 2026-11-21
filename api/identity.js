import {createClient} from '@supabase/supabase-js';
import {randomBytes,createHash} from 'node:crypto';
import {normalizeMatricula,identityEmail} from '../src/identity.js';
export default async function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='POST')return res.status(405).end();
 const e=process.env;if(!e.VITE_SUPABASE_URL||!e.VITE_SUPABASE_PUBLISHABLE_KEY||!e.SUPABASE_SERVICE_ROLE_KEY)return res.status(503).json({error:'Configuração incompleta'});
 const opts={auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}};
 const db=createClient(e.VITE_SUPABASE_URL,e.SUPABASE_SERVICE_ROLE_KEY,opts);
 const auth=createClient(e.VITE_SUPABASE_URL,e.VITE_SUPABASE_PUBLISHABLE_KEY,opts);
 try{const b=typeof req.body==='string'?JSON.parse(req.body):req.body||{};
 if(b.action==='signup'){
  const m=normalizeMatricula(b.matricula), password=b.password, contact=String(b.contact_email||'').trim(), name=String(b.name||'').trim(), department=String(b.department||'').trim();
  if(name.length<2||name.length>120||department.length<1||department.length>120)return res.status(400).json({error:'Informe nome completo e departamento.'});
  if(typeof password!=='string'||password.length<8||password.length>128||contact.length>254||(contact&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact)))return res.status(400).json({error:'Confira a senha e o e-mail informado.'});
  // Limit registrations by network and matrícula. All identifiers are SHA-256 hashes.
  const network=String(req.headers?.['x-vercel-forwarded-for']||req.headers?.['x-real-ip']||req.socket?.remoteAddress||'unknown').split(',')[0].trim();
  const digest=value=>createHash('sha256').update(value).digest('hex');
  for(const [key,limit] of [['ip:'+network,12],['matricula:'+m,4]]){
   const gate=await db.rpc('br_signup_gate',{p_fingerprint:digest(key),p_limit:limit,p_window_minutes:60});
   if(gate.error){console.error('Braveiros limite cadastro:',gate.error.code||gate.error.message);return res.status(503).json({error:'Cadastro temporariamente indisponível. Tente novamente mais tarde.'});}
   if(!gate.data)return res.status(429).json({error:'Muitas tentativas de cadastro. Tente novamente mais tarde.'});
  }
  const existing=await db.from('profiles').select('id').eq('matricula',m).maybeSingle();if(existing.error)throw existing.error;
  if(existing.data)return res.status(400).json({error:'Não foi possível solicitar cadastro. Utilize o login se já possuir conta.'});
  const r=await db.auth.admin.createUser({email:identityEmail(m),password,email_confirm:true,user_metadata:{matricula:m,contact_email:contact,name,department}});
  if(r.error){console.error('Braveiros cadastro',r.error.code||r.error.status);return res.status(r.error.status===429?429:400).json({error:'Cadastro não concluído. Verifique a matrícula com o RH ou solicite suporte à administração.'});}
  return res.status(201).json({success:true});
 }
 if(b.action==='login'){
  const m=normalizeMatricula(b.matricula);if(typeof b.password!=='string'||b.password.length>256)return res.status(400).json({error:'Credenciais inválidas'});
  const lookup=await db.rpc('br_login_email',{p_matricula:m});if(lookup.error)throw lookup.error;
  const r=await auth.auth.signInWithPassword({email:lookup.data||identityEmail(m),password:b.password});
  if(r.error||!r.data.session||!lookup.data)return res.status(401).json({error:'Matrícula ou senha inválida'});
  return res.status(200).json({access_token:r.data.session.access_token,refresh_token:r.data.session.refresh_token});
 }
 const token=(req.headers.authorization||'').match(/^Bearer (\S+)$/i)?.[1];if(!token)return res.status(401).end();
 const u=await db.auth.getUser(token);if(u.error||!u.data.user)return res.status(401).end();
 const id=u.data.user.id;const p=await db.from('profiles').select('*').eq('id',id).single();if(p.error||!p.data.active)return res.status(403).end();
 const session=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString()).session_id;
 const valid=await db.rpc('br_reset_session_ok',{p_id:id,p_session:session});if(valid.error||!valid.data)return res.status(403).json({error:'Sessão expirada. Entre novamente.'});
 if(b.action==='change'){
  if(!p.data.must_change_password||typeof b.password!=='string'||b.password.length<12||b.password.length>128)return res.status(400).json({error:'Use uma senha de 12 a 128 caracteres.'});
  const r=await db.auth.admin.updateUserById(id,{password:b.password});if(r.error)throw r.error;
  const clear=await db.from('profiles').update({must_change_password:false}).eq('id',id).eq('password_reset_at',p.data.password_reset_at).select('id').single();if(clear.error)throw clear.error;
  return res.status(200).json({success:true});
 }
 if(b.action!=='reset'||p.data.role!=='super_admin'||p.data.must_change_password||b.id===id||typeof b.id!=='string')return res.status(403).end();
 const target=await db.from('profiles').select('id,role').eq('id',b.id).single();if(target.error||target.data.role==='super_admin')return res.status(403).json({error:'Redefinição de outro Super Admin não permitida.'});
 const password=randomBytes(18).toString('base64url')+'!a1';
 const lock=await db.from('profiles').update({must_change_password:true,password_reset_at:new Date().toISOString()}).eq('id',b.id);if(lock.error)throw lock.error;
 const r=await db.auth.admin.updateUserById(b.id,{password});if(r.error)throw r.error;
 return res.status(200).json({password});
 }catch(err){console.error('Braveiros identidade',err.code||err.name);return res.status(500).json({error:'Não foi possível concluir. Verifique a configuração e tente novamente.'});}
}
