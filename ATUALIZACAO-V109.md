# Braveiros v1.0.9 | Edição de produto · UX/UI e consolidação

## Resumo

Esta versão mantém os arquivos, tabelas e fluxos da v1.0.8.1, com uma camada de design mais refinada e uma consolidação do painel administrativo. Nenhum arquivo SQL antigo é reexecutado durante a instalação da v1.0.9.

### Interface e experiência

- Feed de visual editorial, com apresentação contextual conforme o horário de Ilhéus, mensagens, publicações e filtros.
- Sidebar desktop com arquitetura organizada: Conexão, Seu dia a dia, Administração.
- Barra inferior no celular, perfil no topo, notificações e busca de conteúdo.
- Cartões de publicações mais legíveis com curtidas, comentários, compartilhamento e indicadores.
- Painel de acesso rápido lateral no computador e menus compactos no celular.
- Tela de login/cadastro com composição visual aprimorada, sem alterar a autenticação.
- Acessibilidade básica: labels, navegação por teclado, contraste, adaptação à largura e respeito a redução de movimento.

### Consistência e acesso

- Remoção da edição administrativa legada de permissões, concentrando alterações em `br_manage_person`.
- Mantidos `br_review_registration` para o Admin e Super Admin, `br_manage_department`/`br_manage_job` para Super Admin.
- Matrícula não precisa constar na antiga lista de autorização; pedido de acesso segue `pending` até avaliação por Admin ou Super Admin.
- Limitador por rede (12 tentativas/hora) e matrícula (4 tentativas/hora), armazenando somente SHA-256 dos identificadores no Supabase.
- Quando o limitador está indisponível, cadastro público falha de forma fechada em vez de prosseguir sem controle.
- Revogação de atualização direta de role/active/department na tabela profiles para usuários autenticados. As funções administrativas SECURITY DEFINER continuam disponíveis.

## Instalação com menor risco

**Antes:** realize backup do banco (especialmente `auth.users`, `public.profiles`, `posts` e `requests`); preserve os secrets da Vercel e anote a URL de deployment de produção atual.

1. Verifique que a **v1.0.8.1** está instalada e funcionando.
2. Supabase → SQL Editor → Execute **somente** `supabase/v109.sql`. A migração cria `public.br_signup_attempts` e `br_signup_gate`, e ajusta permissões legadas. **Não apaga usuários nem posts.**
3. Confirme a migração com:
   ```sql
   SELECT to_regclass('public.br_signup_attempts') AS tabela;
   SELECT proname FROM pg_proc JOIN pg_namespace ON pg_namespace.oid=pg_proc.pronamespace WHERE nspname='public' AND proname='br_signup_gate';
   ```
4. No GitHub, substitua os arquivos do pacote de atualização mantendo a **estrutura de pastas**. Faça o commit na branch `main`.
5. Confira na Vercel as variáveis `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` e, no backend, `SUPABASE_SERVICE_ROLE_KEY`. Não exponha a chave `service_role` e jamais use prefixo `VITE_` nela.
6. Acione seu **Deploy Hook existente** da branch `main`. Não reutilize Redeploy de um commit antigo.
7. Abra o deployment recém-criado. Em **Source**, confirme o `package.json` v1.0.9. Em **Build Logs do mesmo deployment**, confirme `braveiros@1.0.9 build`. O status deve ser `Ready`.
8. Teste o domínio `braveiros.vercel.app` em janela anônima, no celular e no desktop.

### Checklist rápido depois do deploy

- Usuário pré-existente entra com matrícula e senha; seus cargos e permissões permanecem.
- Pessoa nova se cadastra com matrícula livre, nome, setor e senha; fica pendente no painel.
- Admin aprova/recusa; usuário reprovado não entra; aprovado entra.
- Colaborador não vê editor de publicação nem gestão de pessoas.
- Admin vê editor e solicitações, mas não gerencia departamentos/cargos.
- Super Admin gerencia pessoas, departamentos, cargos e pode redefinir senha de colaborador.
- Curtir, comentar e compartilhar funcionam conforme as regras existentes.
- Serviços (SAC, Ouvidoria, transportes, treinamentos, etc.) continuam acessíveis.
- No celular: sem rolagem horizontal, barra inferior visível, campos legíveis.

### Limites conhecidos

- O teste `npm test` roda simulações locais. Não substitui testes no Supabase de produção.
- Não foi possível executar o build completo porque o ambiente de autoria não conseguiu instalar dependências do npm (falha de acesso ao registry). A Vercel fará o build real.
- O SQL **não foi executado no seu Supabase**. Sua aplicação atual permanece inalterada até que você aplique os arquivos.
- Para proteção adicional, habilite WAF/rate limiting no provedor de hospedagem e revise periodicamente a retenção de registros de limitação.
- Matrículas `2323` e `002323` permanecem distintas. Se o RH usar zeros à esquerda, adote um padrão operacional e oriente novos cadastros.
- Agendamento de publicação pode depender de acesso ao app ou configuração separada de rotina pg_cron.

### Reverter

Se ocorrer falha após a publicação: retorne à versão anterior do projeto na Vercel e corrija os arquivos; não reverta o banco às cegas. `supabase/v109.sql` não possui destruição de registros e o limitador é independente do fluxo legado. Para reverter privilégios, use uma migração revisada conforme o banco real.
