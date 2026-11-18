BEGIN;
-- Apply after install.sql and v103.sql, on Braveiros only.
CREATE TABLE IF NOT EXISTS public.br_departments(name text PRIMARY KEY CHECK(length(trim(name)) BETWEEN 1 AND 120),active boolean NOT NULL DEFAULT true);
INSERT INTO public.br_departments(name) SELECT DISTINCT department FROM (SELECT department FROM public.profiles UNION SELECT department FROM public.br_employees) d WHERE length(trim(department)) BETWEEN 1 AND 120 ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS public.br_jobs(department text REFERENCES public.br_departments(name) ON UPDATE CASCADE, name text CHECK(length(trim(name)) BETWEEN 1 AND 120),active boolean NOT NULL DEFAULT true,PRIMARY KEY(department,name));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS job_title text NOT NULL DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_path text;
ALTER TABLE public.br_employees ADD COLUMN IF NOT EXISTS job_title text NOT NULL DEFAULT '';
CREATE TABLE IF NOT EXISTS public.br_people_audit(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),actor uuid DEFAULT auth.uid(),entity text NOT NULL,before_data jsonb,after_data jsonb,created_at timestamptz DEFAULT now());
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS audience text REFERENCES public.br_departments(name) ON UPDATE CASCADE;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS comments_enabled boolean NOT NULL DEFAULT true;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS scheduled_at timestamptz;
CREATE TABLE IF NOT EXISTS public.br_likes(post_id uuid REFERENCES public.posts(id) ON DELETE CASCADE,user_id uuid DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE CASCADE,PRIMARY KEY(post_id,user_id));
CREATE TABLE IF NOT EXISTS public.br_views(post_id uuid REFERENCES public.posts(id) ON DELETE CASCADE,user_id uuid DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE CASCADE,PRIMARY KEY(post_id,user_id));
CREATE TABLE IF NOT EXISTS public.br_comments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE CASCADE,body text NOT NULL CHECK(length(trim(body)) BETWEEN 1 AND 1000),created_at timestamptz DEFAULT now());
CREATE OR REPLACE FUNCTION public.br_feed_visible(p_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT public.br_role() IS NOT NULL AND EXISTS(SELECT 1 FROM public.posts p JOIN public.profiles me ON me.id=auth.uid() WHERE p.id=p_id AND p.kind IN ('news','notice') AND p.published AND (p.scheduled_at IS NULL OR p.scheduled_at<=now()) AND (p.audience IS NULL OR p.audience=me.department) AND (p.kind<>'notice' OR coalesce(p.extra->>'expires','9999-12-31')>=to_char(now() AT TIME ZONE 'America/Bahia','YYYY-MM-DD'))) $$;
REVOKE ALL ON FUNCTION public.br_feed_visible(uuid) FROM public,anon; GRANT EXECUTE ON FUNCTION public.br_feed_visible(uuid) TO authenticated;
DROP POLICY IF EXISTS posts_read ON public.posts;
CREATE POLICY posts_read ON public.posts FOR SELECT TO authenticated USING(public.br_staff() OR (public.br_role() IS NOT NULL AND published AND (kind NOT IN ('news','notice') OR public.br_feed_visible(id))));
GRANT UPDATE(audience,pinned,comments_enabled,scheduled_at) ON public.posts TO authenticated;
ALTER TABLE public.br_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.br_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.br_people_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.br_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.br_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.br_comments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.br_departments,public.br_jobs,public.br_people_audit,public.br_likes,public.br_views,public.br_comments FROM public,anon,authenticated;
GRANT SELECT ON public.br_departments,public.br_jobs,public.br_people_audit TO authenticated;
GRANT SELECT,INSERT,DELETE ON public.br_likes,public.br_comments TO authenticated;
GRANT INSERT,SELECT ON public.br_views TO authenticated;
DROP POLICY IF EXISTS br_dept_read ON public.br_departments;
CREATE POLICY br_dept_read ON public.br_departments FOR SELECT TO authenticated USING(public.br_role()='super_admin');
DROP POLICY IF EXISTS br_jobs_read ON public.br_jobs;
CREATE POLICY br_jobs_read ON public.br_jobs FOR SELECT TO authenticated USING(public.br_role()='super_admin');
DROP POLICY IF EXISTS br_audit_read ON public.br_people_audit;
CREATE POLICY br_audit_read ON public.br_people_audit FOR SELECT TO authenticated USING(public.br_role()='super_admin');
DROP POLICY IF EXISTS br_like_read ON public.br_likes;
CREATE POLICY br_like_read ON public.br_likes FOR SELECT TO authenticated USING(public.br_feed_visible(post_id));
DROP POLICY IF EXISTS br_like_insert ON public.br_likes;
CREATE POLICY br_like_insert ON public.br_likes FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid() AND public.br_feed_visible(post_id));
DROP POLICY IF EXISTS br_like_delete ON public.br_likes;
CREATE POLICY br_like_delete ON public.br_likes FOR DELETE TO authenticated USING(user_id=auth.uid() AND public.br_feed_visible(post_id));
DROP POLICY IF EXISTS br_view_read ON public.br_views;
CREATE POLICY br_view_read ON public.br_views FOR SELECT TO authenticated USING(user_id=auth.uid() AND public.br_feed_visible(post_id));
DROP POLICY IF EXISTS br_view_insert ON public.br_views;
CREATE POLICY br_view_insert ON public.br_views FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid() AND public.br_feed_visible(post_id));
DROP POLICY IF EXISTS br_comment_read ON public.br_comments;
CREATE POLICY br_comment_read ON public.br_comments FOR SELECT TO authenticated USING(public.br_feed_visible(post_id) OR public.br_staff());
DROP POLICY IF EXISTS br_comment_insert ON public.br_comments;
CREATE POLICY br_comment_insert ON public.br_comments FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid() AND public.br_feed_visible(post_id) AND EXISTS(SELECT 1 FROM public.posts p WHERE p.id=post_id AND p.comments_enabled));
DROP POLICY IF EXISTS br_comment_delete ON public.br_comments;
CREATE POLICY br_comment_delete ON public.br_comments FOR DELETE TO authenticated USING(public.br_staff() OR (user_id=auth.uid() AND public.br_feed_visible(post_id)));
-- Only safe display fields leave profiles; never expose email or matrícula through the feed.
CREATE OR REPLACE FUNCTION public.br_social_feed() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(f) ORDER BY f.pinned DESC,f.created_at DESC),'[]'::jsonb) FROM (
 SELECT p.id,p.title,p.body,p.extra,p.kind,p.pinned,p.comments_enabled,p.created_at,p.author,coalesce(a.name,'Cana Brava Resort') author_name,a.avatar_path,
 (SELECT count(*) FROM public.br_likes l WHERE l.post_id=p.id) likes,
 EXISTS(SELECT 1 FROM public.br_likes l WHERE l.post_id=p.id AND l.user_id=auth.uid()) liked,
 (SELECT count(*) FROM public.br_views v WHERE v.post_id=p.id) views,
 (SELECT count(*) FROM public.br_comments c WHERE c.post_id=p.id) comment_count
 FROM public.posts p LEFT JOIN public.profiles a ON a.id=p.author WHERE public.br_feed_visible(p.id) ORDER BY p.pinned DESC,p.created_at DESC LIMIT 200) f $$;
CREATE OR REPLACE FUNCTION public.br_social_comments(p_post uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.created_at),'[]'::jsonb) FROM (SELECT c.id,c.user_id,c.body,c.created_at,p.name FROM public.br_comments c JOIN public.profiles p ON p.id=c.user_id WHERE c.post_id=p_post AND (public.br_feed_visible(p_post) OR public.br_staff()) ORDER BY c.created_at DESC LIMIT 200) c $$;
CREATE OR REPLACE FUNCTION public.br_departments_list() RETURNS SETOF public.br_departments LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT * FROM public.br_departments WHERE public.br_staff() ORDER BY name $$;
CREATE OR REPLACE FUNCTION public.br_audit_people() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF TG_TABLE_NAME='profiles' THEN
 IF (NEW.name,NEW.department,NEW.job_title,NEW.role,NEW.active) IS NOT DISTINCT FROM (OLD.name,OLD.department,OLD.job_title,OLD.role,OLD.active) THEN RETURN NEW; END IF;
 INSERT INTO public.br_people_audit(entity,before_data,after_data) VALUES(TG_TABLE_NAME,jsonb_build_object('id',OLD.id,'name',OLD.name,'department',OLD.department,'job',OLD.job_title,'role',OLD.role,'active',OLD.active),jsonb_build_object('id',NEW.id,'name',NEW.name,'department',NEW.department,'job',NEW.job_title,'role',NEW.role,'active',NEW.active));
 ELSE INSERT INTO public.br_people_audit(entity,before_data,after_data) VALUES(TG_TABLE_NAME,CASE WHEN TG_OP='UPDATE' THEN to_jsonb(OLD) END,to_jsonb(NEW)); END IF; RETURN NEW; END $$;
DROP TRIGGER IF EXISTS br_audit_profile ON public.profiles; CREATE TRIGGER br_audit_profile AFTER UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.br_audit_people();
DROP TRIGGER IF EXISTS br_audit_dept ON public.br_departments; CREATE TRIGGER br_audit_dept AFTER INSERT OR UPDATE ON public.br_departments FOR EACH ROW EXECUTE FUNCTION public.br_audit_people();
DROP TRIGGER IF EXISTS br_audit_job ON public.br_jobs; CREATE TRIGGER br_audit_job AFTER INSERT OR UPDATE ON public.br_jobs FOR EACH ROW EXECUTE FUNCTION public.br_audit_people();
CREATE OR REPLACE FUNCTION public.br_manage_department(p_old text,p_name text,p_active boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF public.br_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 p_name:=trim(p_name); IF p_old IS NULL THEN INSERT INTO public.br_departments VALUES(p_name,p_active); ELSE UPDATE public.br_departments SET name=p_name,active=p_active WHERE name=p_old; IF NOT FOUND THEN RAISE EXCEPTION 'Departamento inexistente'; END IF; UPDATE public.profiles SET department=p_name WHERE department=p_old; UPDATE public.br_employees SET department=p_name WHERE department=p_old; END IF; END $$;
CREATE OR REPLACE FUNCTION public.br_manage_job(p_department text,p_old text,p_name text,p_active boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF public.br_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 p_name:=trim(p_name); IF p_old IS NULL THEN INSERT INTO public.br_jobs VALUES(p_department,p_name,p_active); ELSE UPDATE public.br_jobs SET name=p_name,active=p_active WHERE department=p_department AND name=p_old; IF NOT FOUND THEN RAISE EXCEPTION 'Cargo inexistente'; END IF; UPDATE public.profiles SET job_title=p_name WHERE department=p_department AND job_title=p_old; UPDATE public.br_employees SET job_title=p_name WHERE department=p_department AND job_title=p_old; END IF; END $$;
CREATE OR REPLACE FUNCTION public.br_manage_person(p_id uuid,p_name text,p_department text,p_job text,p_role text,p_active boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ DECLARE m text; BEGIN
 IF public.br_role() IS DISTINCT FROM 'super_admin' OR (p_id=auth.uid() AND (p_role<>'super_admin' OR NOT p_active)) THEN RAISE EXCEPTION 'Acesso restrito ou alteração do próprio acesso'; END IF;
 IF length(trim(p_name)) NOT BETWEEN 1 AND 120 OR NOT EXISTS(SELECT 1 FROM public.br_departments WHERE name=p_department AND active) OR (p_job<>'' AND NOT EXISTS(SELECT 1 FROM public.br_jobs WHERE department=p_department AND name=p_job AND active)) THEN RAISE EXCEPTION 'Dados profissionais inválidos'; END IF;
 UPDATE public.profiles SET name=trim(p_name),department=p_department,job_title=p_job,role=p_role,active=p_active WHERE id=p_id RETURNING matricula INTO m; IF NOT FOUND THEN RAISE EXCEPTION 'Perfil inexistente'; END IF;
 UPDATE public.br_employees SET name=trim(p_name),department=p_department,job_title=p_job WHERE matricula=m; END $$;
CREATE OR REPLACE FUNCTION public.br_set_avatar(p_path text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN IF public.br_role() IS NULL OR (p_path IS NOT NULL AND split_part(p_path,'/',1)<>auth.uid()::text) THEN RAISE EXCEPTION 'Acesso restrito'; END IF; UPDATE public.profiles SET avatar_path=p_path WHERE id=auth.uid(); END $$;
-- Keep original CSV format valid; optional fourth field is job_title.
CREATE OR REPLACE FUNCTION public.br_import_employees(p_rows jsonb) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ DECLARE r jsonb; n integer:=0; m text; nm text; dp text; j text; BEGIN
 IF public.br_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR jsonb_array_length(p_rows)>500 THEN RAISE EXCEPTION 'Limite de 500 registros'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_rows) LOOP m:=r->>'matricula';nm:=trim(r->>'name');dp:=trim(r->>'department');j:=trim(r->>'job_title');
 IF m IS NULL OR m !~ '^[0-9]{1,20}$' OR nm IS NULL OR length(nm) NOT BETWEEN 1 AND 120 OR dp IS NULL OR length(dp) NOT BETWEEN 1 AND 120 OR length(j)>120 THEN RAISE EXCEPTION 'Linha inválida'; END IF;
 INSERT INTO public.br_departments(name) VALUES(dp) ON CONFLICT DO NOTHING;
 IF coalesce(j,'')<>'' THEN INSERT INTO public.br_jobs(department,name) VALUES(dp,j) ON CONFLICT DO NOTHING; END IF;
 INSERT INTO public.br_employees(matricula,name,department,job_title) VALUES(m,nm,dp,coalesce(j,'')) ON CONFLICT(matricula) DO UPDATE SET name=excluded.name,department=excluded.department,job_title=CASE WHEN j IS NOT NULL THEN j WHEN br_employees.department=dp THEN br_employees.job_title ELSE '' END;
 UPDATE public.profiles SET name=nm,department=dp,job_title=CASE WHEN j IS NOT NULL THEN j WHEN department=dp THEN job_title ELSE '' END WHERE matricula=m; n:=n+1; END LOOP; RETURN n; END $$;
CREATE OR REPLACE FUNCTION public.br_sync_job() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN IF NEW.matricula IS NOT NULL AND (TG_OP='INSERT' OR NEW.matricula IS DISTINCT FROM OLD.matricula) THEN SELECT coalesce(e.job_title,'') INTO NEW.job_title FROM public.br_employees e WHERE e.matricula=NEW.matricula; NEW.job_title:=coalesce(NEW.job_title,''); END IF; RETURN NEW; END $$;
DROP TRIGGER IF EXISTS br_sync_job ON public.profiles; CREATE TRIGGER br_sync_job BEFORE INSERT OR UPDATE OF matricula ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.br_sync_job();
-- Private media: authentication required, targeted posts restrict media reads too.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('br-feed','br-feed',false,52428800,ARRAY['image/jpeg','image/png','image/webp','video/mp4','video/webm']),('br-avatars','br-avatars',false,5242880,ARRAY['image/jpeg','image/png','image/webp']) ON CONFLICT(id) DO NOTHING;
DROP POLICY IF EXISTS br_media_insert ON storage.objects;
CREATE POLICY br_media_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='br-feed' AND public.br_staff() AND (storage.foldername(name))[1]=auth.uid()::text);
DROP POLICY IF EXISTS br_media_read ON storage.objects;
CREATE POLICY br_media_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='br-feed' AND (public.br_staff() OR EXISTS(SELECT 1 FROM public.posts p WHERE public.br_feed_visible(p.id) AND p.extra->'media' @> jsonb_build_array(jsonb_build_object('path',name)))));
DROP POLICY IF EXISTS br_avatar_insert ON storage.objects;
CREATE POLICY br_avatar_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='br-avatars' AND public.br_role() IS NOT NULL AND (storage.foldername(name))[1]=auth.uid()::text);
DROP POLICY IF EXISTS br_avatar_read ON storage.objects;
CREATE POLICY br_avatar_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='br-avatars' AND public.br_role() IS NOT NULL);
-- Publish scheduled items via periodic client RPC or optional pg_cron. Notification queue uses existing infrastructure.
CREATE OR REPLACE FUNCTION public.br_notice() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN IF new.kind IN ('notice','news') AND new.published AND (new.scheduled_at IS NULL OR new.scheduled_at<=now()) AND (TG_OP='INSERT' OR old.published IS DISTINCT FROM new.published) THEN
 INSERT INTO public.notifications(user_id,post_id,title) SELECT id,new.id,new.title FROM public.profiles WHERE active AND id<>new.author AND (new.audience IS NULL OR department=new.audience) ON CONFLICT DO NOTHING;
 INSERT INTO public.push_queue(notification_id,endpoint) SELECT n.id,d.endpoint FROM public.notifications n JOIN public.devices d ON d.user_id=n.user_id WHERE n.post_id=new.id ON CONFLICT DO NOTHING; END IF; RETURN NEW; END $$;
CREATE OR REPLACE FUNCTION public.br_publish_due() RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ UPDATE public.posts SET published=true WHERE kind IN ('news','notice') AND NOT published AND scheduled_at IS NOT NULL AND scheduled_at<=now() AND (public.br_role() IS NOT NULL OR auth.uid() IS NULL) $$;
REVOKE ALL ON FUNCTION public.br_social_feed(),public.br_social_comments(uuid),public.br_departments_list(),public.br_manage_department(text,text,boolean),public.br_manage_job(text,text,text,boolean),public.br_manage_person(uuid,text,text,text,text,boolean),public.br_set_avatar(text),public.br_publish_due() FROM public,anon;
GRANT EXECUTE ON FUNCTION public.br_social_feed(),public.br_social_comments(uuid),public.br_departments_list(),public.br_manage_department(text,text,boolean),public.br_manage_job(text,text,text,boolean),public.br_manage_person(uuid,text,text,text,text,boolean),public.br_set_avatar(text),public.br_publish_due() TO authenticated;
REVOKE ALL ON FUNCTION public.br_audit_people(),public.br_sync_job() FROM public,anon,authenticated;
DROP POLICY IF EXISTS notification_read ON public.notifications;
CREATE POLICY notification_read ON public.notifications FOR SELECT TO authenticated USING(user_id=auth.uid() AND public.br_role() IS NOT NULL AND (post_id IS NULL OR public.br_feed_visible(post_id)));
CREATE OR REPLACE FUNCTION public.br_claim() RETURNS TABLE(job_id bigint,endpoint text,subscription jsonb,title text,notification_id uuid,attempts integer) LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
WITH picked AS (SELECT q.id FROM public.push_queue q JOIN public.notifications n ON n.id=q.notification_id JOIN public.profiles p ON p.id=n.user_id AND p.active JOIN public.posts s ON s.id=n.post_id AND s.published AND (s.scheduled_at IS NULL OR s.scheduled_at<=now()) AND (s.audience IS NULL OR s.audience=p.department) AND (s.kind<>'notice' OR coalesce(s.extra->>'expires','9999-12-31') >= to_char(now() at time zone 'America/Bahia','YYYY-MM-DD')) JOIN public.devices d ON d.endpoint=q.endpoint AND d.user_id=n.user_id WHERE q.status IN ('pending','sending') AND q.next_at<=now() AND q.attempts<5 AND n.created_at>now()-interval '24 hours' ORDER BY q.id LIMIT 30 FOR UPDATE OF q SKIP LOCKED),claimed AS(UPDATE public.push_queue q SET status='sending',attempts=q.attempts+1,next_at=now()+interval '5 minutes' FROM picked WHERE q.id=picked.id RETURNING q.*) SELECT c.id,d.endpoint,d.subscription,n.title,n.id,c.attempts FROM claimed c JOIN public.devices d ON d.endpoint=c.endpoint JOIN public.notifications n ON n.id=c.notification_id $$;
NOTIFY pgrst,'reload schema';
COMMIT;
