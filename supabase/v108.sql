BEGIN;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS registration_status text CHECK (registration_status IN ('pending','approved','rejected'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS registration_reviewed_at timestamptz;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS registration_reviewed_by uuid;
-- Preserve existing active and inactive accounts; pre-existing inactive employees remain reviewable.
UPDATE public.profiles SET registration_status=CASE WHEN active THEN 'approved' ELSE 'pending' END WHERE registration_status IS NULL AND matricula IS NOT NULL;
CREATE OR REPLACE FUNCTION public.br_new_user() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m text:=new.raw_user_meta_data->>'matricula'; e public.br_employees%ROWTYPE;
BEGIN
 IF m IS NULL OR m !~ '^[0-9]{1,20}$' OR lower(coalesce(new.email,'')) <> m||'@login.braveiros.example.com' THEN RAISE EXCEPTION 'Cadastro por matrícula obrigatório'; END IF;
 SELECT * INTO e FROM public.br_employees WHERE matricula=m AND active FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Matrícula indisponível'; END IF;
 INSERT INTO public.profiles(id,name,department,matricula,contact_email,role,active,registration_status) VALUES(new.id,e.name,e.department,m,left(nullif(new.raw_user_meta_data->>'contact_email',''),254),'employee',false,'pending');
 RETURN new;
END; $$;
-- Dedicated approval: admins may approve only employees, not elevate roles.
CREATE TABLE IF NOT EXISTS public.br_registration_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 profile_id uuid NOT NULL, reviewer_id uuid, decision text NOT NULL CHECK(decision IN ('approved','rejected')), reviewed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.br_registration_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.br_registration_audit FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.br_registration_audit TO authenticated;
DROP POLICY IF EXISTS br_registration_audit_read ON public.br_registration_audit;
CREATE POLICY br_registration_audit_read ON public.br_registration_audit FOR SELECT TO authenticated USING(public.br_staff());
CREATE OR REPLACE FUNCTION public.br_review_registration(p_id uuid,p_approve boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target public.profiles%ROWTYPE;
BEGIN
 IF public.br_staff() IS DISTINCT FROM true OR p_id=auth.uid() OR p_approve IS NULL THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 SELECT * INTO target FROM public.profiles WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR target.role<>'employee' OR target.registration_status IS DISTINCT FROM 'pending' OR target.active THEN RAISE EXCEPTION 'Solicitação não disponível'; END IF;
 IF p_approve AND NOT EXISTS(SELECT 1 FROM public.br_employees WHERE matricula=target.matricula AND active) THEN RAISE EXCEPTION 'Matrícula não autorizada ou bloqueada'; END IF;
 UPDATE public.profiles SET active=p_approve,registration_status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,registration_reviewed_at=now(),registration_reviewed_by=auth.uid() WHERE id=p_id;
END; $$;
REVOKE ALL ON FUNCTION public.br_review_registration(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.br_review_registration(uuid,boolean) TO authenticated;
-- Keep legacy Super Admin activation synchronized with registration state.
CREATE OR REPLACE FUNCTION public.br_registration_sync() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.active AND NOT OLD.active AND OLD.registration_status IN ('pending','rejected') THEN
  NEW.registration_status:='approved'; NEW.registration_reviewed_at:=now(); NEW.registration_reviewed_by:=auth.uid();
 END IF;
 RETURN NEW;
END; $$;
CREATE OR REPLACE FUNCTION public.br_registration_log() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.registration_reviewed_at IS DISTINCT FROM OLD.registration_reviewed_at AND NEW.registration_status IN ('approved','rejected') THEN
  INSERT INTO public.br_registration_audit(profile_id,reviewer_id,decision,reviewed_at) VALUES(NEW.id,NEW.registration_reviewed_by,NEW.registration_status,NEW.registration_reviewed_at);
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS br_registration_log ON public.profiles;
CREATE TRIGGER br_registration_log AFTER UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.br_registration_log();
DROP TRIGGER IF EXISTS br_registration_sync ON public.profiles;
CREATE TRIGGER br_registration_sync BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.br_registration_sync();
NOTIFY pgrst,'reload schema';
COMMIT;
