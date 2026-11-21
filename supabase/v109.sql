-- Braveiros v1.0.9 | Consolidação, registro e proteção do cadastro.
-- Executar apenas após as migrações v1.0.7, v1.0.8 e v1.0.8.1.
-- Não exclui usuários, perfis, publicações ou departamentos.
BEGIN;
CREATE TABLE IF NOT EXISTS public.br_signup_attempts (
 fingerprint text NOT NULL,
 bucket_start timestamptz NOT NULL,
 attempts integer NOT NULL DEFAULT 1,
 PRIMARY KEY(fingerprint,bucket_start),
 CONSTRAINT br_signup_fingerprint_check CHECK(fingerprint ~ '^[0-9a-f]{64}$'),
 CONSTRAINT br_signup_attempts_positive CHECK(attempts > 0)
);
ALTER TABLE public.br_signup_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.br_signup_attempts FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.br_signup_attempts TO service_role;

CREATE OR REPLACE FUNCTION public.br_signup_gate(p_fingerprint text,p_limit integer DEFAULT 12,p_window_minutes integer DEFAULT 60)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE n integer; bucket timestamptz;
BEGIN
 IF current_user <> 'postgres' AND auth.role() <> 'service_role' THEN RAISE EXCEPTION 'Acesso restrito'; END IF;
 IF p_fingerprint IS NULL OR p_fingerprint !~ '^[0-9a-f]{64}$' OR p_limit < 1 OR p_limit > 100 OR p_window_minutes < 1 OR p_window_minutes > 1440 THEN RAISE EXCEPTION 'Parâmetros inválidos'; END IF;
 bucket:=to_timestamp(floor(extract(epoch from now())/(p_window_minutes*60))*(p_window_minutes*60));
 INSERT INTO public.br_signup_attempts(fingerprint,bucket_start,attempts)
 VALUES(p_fingerprint,bucket,1)
 ON CONFLICT(fingerprint,bucket_start) DO UPDATE SET attempts=public.br_signup_attempts.attempts+1
 RETURNING attempts INTO n;
 RETURN n<=p_limit;
END; $$;
REVOKE ALL ON FUNCTION public.br_signup_gate(text,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.br_signup_gate(text,integer,integer) TO service_role;

-- Evita que telas legadas contornem a aprovação por RPC.
-- A administração já deve usar br_review_registration e br_manage_person.
REVOKE ALL ON FUNCTION public.br_import_employees(jsonb),public.br_employee_active(text,boolean) FROM PUBLIC,anon,authenticated;
-- A gestão de perfis agora passa exclusivamente pelas funções administrativas verificadas.
-- O código não depende de UPDATE direto em public.profiles com credenciais de usuário.
REVOKE UPDATE(role,active,department) ON public.profiles FROM authenticated;
DROP POLICY IF EXISTS profile_manage ON public.profiles;
-- Preserva identidade histórica e o fluxo de matrículas informadas livremente.
-- Não altera public.br_new_user nem a função de autorização do cadastro.
NOTIFY pgrst,'reload schema';
COMMIT;
-- Limpeza opcional para uso em rotina de manutenção (NÃO é executada neste SQL):
-- DELETE FROM public.br_signup_attempts WHERE bucket_start < now()-interval '7 days';
