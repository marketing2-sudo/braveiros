-- Braveiros v1.1.0 | Social Experience
-- Pré-requisito: migrações até v1.0.9 aplicadas.
-- Cria stories e mídia privada. NÃO remove usuários, publicações ou dados existentes.
BEGIN;
CREATE TABLE IF NOT EXISTS public.br_stories (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 author uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id),
 title text NOT NULL CHECK(length(btrim(title)) BETWEEN 1 AND 60),
 body text NOT NULL DEFAULT '' CHECK(length(body)<=300),
 media_path text NOT NULL CHECK(length(media_path) BETWEEN 3 AND 500),
 media_type text NOT NULL CHECK(media_type IN ('image/jpeg','image/png','image/webp','video/mp4','video/webm')),
 audience text REFERENCES public.br_departments(name) ON UPDATE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
 CONSTRAINT br_story_valid_timing CHECK(expires_at > created_at)
);
CREATE INDEX IF NOT EXISTS br_stories_active_idx ON public.br_stories(expires_at DESC,created_at DESC);
ALTER TABLE public.br_stories ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.br_stories FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,DELETE ON public.br_stories TO authenticated;

CREATE OR REPLACE FUNCTION public.br_story_visible(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.br_role() IS NOT NULL AND EXISTS (
  SELECT 1 FROM public.br_stories s JOIN public.profiles me ON me.id=auth.uid()
  WHERE s.id=p_id AND s.expires_at>now() AND (s.audience IS NULL OR s.audience=me.department)
 )
$$;
REVOKE ALL ON FUNCTION public.br_story_visible(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.br_story_visible(uuid) TO authenticated;
DROP POLICY IF EXISTS br_story_read ON public.br_stories;
CREATE POLICY br_story_read ON public.br_stories FOR SELECT TO authenticated USING (public.br_story_visible(id) OR public.br_staff());
DROP POLICY IF EXISTS br_story_insert ON public.br_stories;
CREATE POLICY br_story_insert ON public.br_stories FOR INSERT TO authenticated
 WITH CHECK (public.br_staff() AND author=auth.uid() AND split_part(media_path,'/',1)=auth.uid()::text
 AND expires_at>now() AND expires_at<=now()+interval '25 hours');
DROP POLICY IF EXISTS br_story_delete ON public.br_stories;
CREATE POLICY br_story_delete ON public.br_stories FOR DELETE TO authenticated USING (public.br_staff());

CREATE OR REPLACE FUNCTION public.br_stories_feed()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.created_at DESC),'[]'::jsonb)
 FROM (
  SELECT st.id,st.author,st.title,st.body,st.media_path,st.media_type,st.created_at,st.expires_at,
  coalesce(p.name,'Cana Brava Resort') AS author_name,p.avatar_path
  FROM public.br_stories st LEFT JOIN public.profiles p ON p.id=st.author
  WHERE public.br_story_visible(st.id)
  ORDER BY st.created_at DESC LIMIT 80
 ) s
$$;
REVOKE ALL ON FUNCTION public.br_stories_feed() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.br_stories_feed() TO authenticated;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES ('br-stories','br-stories',false,26214400,ARRAY['image/jpeg','image/png','image/webp','video/mp4','video/webm'])
 ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=26214400,
 allowed_mime_types=ARRAY['image/jpeg','image/png','image/webp','video/mp4','video/webm'];
DROP POLICY IF EXISTS br_story_media_upload ON storage.objects;
CREATE POLICY br_story_media_upload ON storage.objects FOR INSERT TO authenticated
 WITH CHECK (bucket_id='br-stories' AND public.br_staff() AND (storage.foldername(name))[1]=auth.uid()::text);
DROP POLICY IF EXISTS br_story_media_view ON storage.objects;
CREATE POLICY br_story_media_view ON storage.objects FOR SELECT TO authenticated
 USING (bucket_id='br-stories' AND (public.br_staff() OR EXISTS (
  SELECT 1 FROM public.br_stories st WHERE st.media_path=name AND public.br_story_visible(st.id)
 )));
-- Não há política UPDATE ou DELETE de arquivos. Um administrador pode excluir o registro do story.
-- Os arquivos permanecem privados; a limpeza física pode ser feita por rotina administrativa posterior.
NOTIFY pgrst,'reload schema';
COMMIT;
