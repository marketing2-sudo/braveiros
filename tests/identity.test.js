import test from 'node:test';import assert from 'node:assert/strict';import {normalizeMatricula,identityEmail,parseEmployees} from '../src/identity.js';
test('preserves leading zeros',()=>assert.equal(identityEmail(' 00125 '),'00125@login.braveiros.example.com'));
test('rejects invalid IDs',()=>{for(const m of ['','1e3','a12','1 2','1.2'])assert.throws(()=>normalizeMatricula(m))});
test('reads Excel CSV with BOM and semicolon',()=>assert.deepEqual(parseEmployees('\uFEFFMatrícula;Nome;Departamento\r\n001;Ana;RH'),[{matricula:'001',name:'Ana',department:'RH'}]));
test('quoted comma and escaped quotes',()=>assert.equal(parseEmployees('matricula,nome,departamento\n1,"Ana, \"\"A\"\"",RH')[0].name,'Ana, "A"'));
test('rejects duplicate IDs',()=>assert.throws(()=>parseEmployees('matricula;nome;departamento\n01;Ana;RH\n01;B;RH')));
test('rejects missing fields',()=>assert.throws(()=>parseEmployees('matricula;nome;departamento\n01;Ana;')));

test('optional CSV job preserves leading zeros',()=>{assert.deepEqual(parseEmployees('matricula;nome;departamento;cargo\n001;Ana;Marketing;Analista'),[{matricula:'001',name:'Ana',department:'Marketing',job_title:'Analista'}]);});
