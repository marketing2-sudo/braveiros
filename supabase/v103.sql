BEGIN;
-- Execute somente no banco Braveiros, após install.sql.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS matricula text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS contact_email text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password_reset_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS br_profiles_matricula_unique ON public.profiles(matricula) WHERE matricula IS NOT NULL;
CREATE TABLE IF NOT EXISTS public.br_employees (
 matricula text PRIMARY KEY CHECK(matricula ~ '^[0-9]{1,20}$'),
 name text NOT NULL CHECK(length(name) BETWEEN 1 AND 120),
 department text NOT NULL CHECK(length(department) BETWEEN 1 AND 120),
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.br_employees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.br_employees FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.br_employees TO authenticated;
GRANT SELECT ON public.br_employees TO service_role;
GRANT SELECT,UPDATE ON public.profiles TO service_role;
-- Corrige contas criadas antes do gatilho, sem conceder acesso automaticamente.
INSERT INTO public.profiles(id,name,department,contact_email)
SELECT u.id,left(coalesce(nullif(u.raw_user_meta_data->>'name',''),'Colaborador'),120),left(coalesce(u.raw_user_meta_data->>'department',''),120),u.email
FROM auth.users u ON CONFLICT(id) DO NOTHING;
CREATE OR REPLACE FUNCTION public.br_new_user() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m text:=new.raw_user_meta_data->>'matricula'; e public.br_employees%ROWTYPE;
BEGIN
 IF m IS NULL OR m !~ '^[0-9]{1,20}$' OR lower(coalesce(new.email,'')) <> m||'@login.braveiros.example.com' THEN RAISE EXCEPTION 'Cadastro por matrícula obrigatório'; END IF;
 SELECT * INTO e FROM public.br_employees WHERE matricula=m AND active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Matrícula indisponível'; END IF;
 INSERT INTO public.profiles(id,name,department,matricula,contact_email) VALUES(new.id,e.name,e.department,m,left(nullif(new.raw_user_meta_data->>'contact_email',''),254));
 RETURN new;
END; $$;
DROP TRIGGER IF EXISTS br_new_user ON auth.users;
CREATE TRIGGER br_new_user AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.br_new_user();
-- Sessões anteriores à redefinição deixam de autorizar conteúdo, inclusive após refresh.
CREATE OR REPLACE FUNCTION public.br_session_current(p_id uuid,p_cutoff timestamptz) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT p_cutoff IS NULL OR EXISTS(SELECT 1 FROM auth.sessions s WHERE s.user_id=p_id AND s.id::text=auth.jwt()->>'session_id' AND s.created_at>p_cutoff);
$$;
REVOKE ALL ON FUNCTION public.br_session_current(uuid,timestamptz) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.br_role() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT p.role FROM public.profiles p WHERE p.id=auth.uid() AND p.active AND NOT p.must_change_password AND public.br_session_current(p.id,p.password_reset_at) AND (p.matricula IS NULL OR EXISTS(SELECT 1 FROM public.br_employees e WHERE e.matricula=p.matricula AND e.active));
$$;
DROP POLICY IF EXISTS br_employees_read ON public.br_employees;
CREATE POLICY br_employees_read ON public.br_employees FOR SELECT TO authenticated USING(public.br_role()='super_admin');
CREATE OR REPLACE FUNCTION public.br_import_employees(p_rows jsonb) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r jsonb; n integer:=0; m text; nm text; dp text;
BEGIN
 IF public.br_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR jsonb_array_length(p_rows)>500 THEN RAISE EXCEPTION 'Limite de 500 registros'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
  m:=r->>'matricula'; nm:=trim(r->>'name'); dp:=trim(r->>'department');
  IF m IS NULL OR m !~ '^[0-9]{1,20}$' OR nm IS NULL OR length(nm) NOT BETWEEN 1 AND 120 OR dp IS NULL OR length(dp) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'Linha inválida na importação'; END IF;
  INSERT INTO public.br_employees(matricula,name,department) VALUES(m,nm,dp) ON CONFLICT(matricula) DO UPDATE SET name=excluded.name,department=excluded.department;
  UPDATE public.profiles SET name=nm,department=dp WHERE matricula=m;
  n:=n+1;
 END LOOP; RETURN n;
END; $$;
CREATE OR REPLACE FUNCTION public.br_employee_active(p_matricula text,p_active boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF public.br_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 IF EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND matricula=p_matricula) THEN RAISE EXCEPTION 'Não altere seu próprio vínculo'; END IF;
 UPDATE public.br_employees SET active=p_active WHERE matricula=p_matricula;
 IF NOT FOUND THEN RAISE EXCEPTION 'Matrícula inexistente'; END IF;
 IF NOT p_active THEN
  UPDATE public.profiles SET active=false WHERE matricula=p_matricula;
  DELETE FROM public.devices WHERE user_id IN(SELECT id FROM public.profiles WHERE matricula=p_matricula);
 END IF;
END; $$;
CREATE OR REPLACE FUNCTION public.br_link_employee(p_id uuid,p_matricula text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.br_employees%ROWTYPE;
BEGIN
 IF public.br_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 SELECT * INTO e FROM public.br_employees WHERE matricula=p_matricula AND active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Matrícula não autorizada'; END IF;
 UPDATE public.profiles SET matricula=e.matricula,name=e.name,department=e.department WHERE id=p_id AND matricula IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'Perfil inexistente ou já vinculado'; END IF;
END; $$;
-- A API privada resolve contas legadas por matrícula sem revelar o e-mail.
CREATE OR REPLACE FUNCTION public.br_login_email(p_matricula text) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT u.email FROM auth.users u JOIN public.profiles p ON p.id=u.id JOIN public.br_employees e ON e.matricula=p.matricula AND e.active WHERE p.matricula=p_matricula;
$$;
CREATE OR REPLACE FUNCTION public.br_reset_session_ok(p_id uuid,p_session text) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.profiles p JOIN auth.sessions s ON s.user_id=p.id WHERE p.id=p_id AND p.active AND s.id::text=p_session AND (p.password_reset_at IS NULL OR s.created_at>p.password_reset_at) AND (p.matricula IS NULL OR EXISTS(SELECT 1 FROM public.br_employees e WHERE e.matricula=p.matricula AND e.active)));
$$;
REVOKE ALL ON FUNCTION public.br_login_email(text),public.br_reset_session_ok(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.br_login_email(text),public.br_reset_session_ok(uuid,text) TO service_role;
REVOKE ALL ON FUNCTION public.br_import_employees(jsonb),public.br_employee_active(text,boolean),public.br_link_employee(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.br_import_employees(jsonb),public.br_employee_active(text,boolean),public.br_link_employee(uuid,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.br_check_profile_activation() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.active AND NEW.matricula IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.br_employees WHERE matricula=NEW.matricula AND active) THEN RAISE EXCEPTION 'Matrícula inativa'; END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS br_check_profile_activation ON public.profiles;
CREATE TRIGGER br_check_profile_activation BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.br_check_profile_activation();
NOTIFY pgrst,'reload schema';
COMMIT;
