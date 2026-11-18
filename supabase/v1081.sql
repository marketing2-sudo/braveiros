BEGIN;
-- v1.0.8.1: preservar contas e cadastro histórico; remover dependência da lista prévia.
CREATE OR REPLACE FUNCTION public.br_new_user() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m text:=new.raw_user_meta_data->>'matricula'; nm text:=trim(coalesce(new.raw_user_meta_data->>'name','')); dp text:=trim(coalesce(new.raw_user_meta_data->>'department',''));
BEGIN
 IF m IS NULL OR m !~ '^[0-9]{1,20}$' OR lower(coalesce(new.email,'')) <> m||'@login.braveiros.example.com' THEN RAISE EXCEPTION 'Cadastro por matrícula obrigatório'; END IF;
 IF length(nm) NOT BETWEEN 2 AND 120 OR length(dp) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'Nome e departamento obrigatórios'; END IF;
 INSERT INTO public.profiles(id,name,department,matricula,contact_email,role,active,registration_status) VALUES(new.id,nm,dp,m,left(nullif(new.raw_user_meta_data->>'contact_email',''),254),'employee',false,'pending');
 RETURN new;
END; $$;
CREATE OR REPLACE FUNCTION public.br_role() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT p.role FROM public.profiles p WHERE p.id=auth.uid() AND p.active AND NOT p.must_change_password AND public.br_session_current(p.id,p.password_reset_at);
$$;
CREATE OR REPLACE FUNCTION public.br_login_email(p_matricula text) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT u.email FROM auth.users u JOIN public.profiles p ON p.id=u.id WHERE p.matricula=p_matricula;
$$;
CREATE OR REPLACE FUNCTION public.br_reset_session_ok(p_id uuid,p_session text) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.profiles p JOIN auth.sessions s ON s.user_id=p.id WHERE p.id=p_id AND p.active AND s.id::text=p_session AND (p.password_reset_at IS NULL OR s.created_at>p.password_reset_at));
$$;
CREATE OR REPLACE FUNCTION public.br_review_registration(p_id uuid,p_approve boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target public.profiles%ROWTYPE;
BEGIN
 IF public.br_staff() IS DISTINCT FROM true OR p_id=auth.uid() OR p_approve IS NULL THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 SELECT * INTO target FROM public.profiles WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR target.role<>'employee' OR target.registration_status IS DISTINCT FROM 'pending' OR target.active THEN RAISE EXCEPTION 'Solicitação não disponível'; END IF;

 UPDATE public.profiles SET active=p_approve,registration_status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,registration_reviewed_at=now(),registration_reviewed_by=auth.uid() WHERE id=p_id;
END; $$;
CREATE OR REPLACE FUNCTION public.br_link_employee(p_id uuid,p_matricula text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF public.br_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 IF p_matricula IS NULL OR p_matricula !~ '^[0-9]{1,20}$' THEN RAISE EXCEPTION 'Matrícula inválida'; END IF;
 UPDATE public.profiles SET matricula=p_matricula WHERE id=p_id AND matricula IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'Perfil inexistente ou já vinculado'; END IF;
END; $$;
DROP TRIGGER IF EXISTS br_check_profile_activation ON public.profiles;
DROP TRIGGER IF EXISTS br_sync_job ON public.profiles;
REVOKE EXECUTE ON FUNCTION public.br_import_employees(jsonb),public.br_employee_active(text,boolean) FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
