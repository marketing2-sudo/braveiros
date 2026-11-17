-- Consulta somente leitura, após instalar.
select tablename,rowsecurity from pg_tables where schemaname='public' and tablename in ('profiles','posts','requests','votes','progress','notifications','devices','push_queue') order by tablename;
select to_regprocedure('public.br_claim()') as fila_push,to_regprocedure('public.br_vote(uuid,text)') as enquetes,to_regprocedure('public.br_register_device(jsonb)') as dispositivos;
select status,count(*) from public.push_queue group by status;
