# Braveiros v1.0 · Nosso portal

Projeto independente para colaboradores do Cana Brava Resort. Vite + JavaScript modular (sem React), Supabase Auth/Postgres, PWA, funções Vercel para push. Não compartilha banco, autenticação ou chaves com BravaDesk. O layout utiliza verde-musgo, areia, superfícies discretas, navegação inferior mobile, lateral desktop e tema escuro. O símbolo tipográfico provisório pode ser substituído pela marca oficial.

## 1. Criar o banco

1. Crie um projeto NOVO em https://supabase.com/dashboard. Não execute a migração no banco do BravaDesk.
2. SQL Editor > New query: cole o conteúdo inteiro de `supabase/install.sql`, do BEGIN ao COMMIT. Execute uma vez, em banco novo. Se der erro, não execute parcialmente; registre a primeira mensagem.
3. Execute `supabase/diagnostico.sql`. As oito tabelas devem aparecer com RLS ativado e as três funções devem existir.
4. Authentication > Providers > Email: habilite login por e-mail. Mantenha confirmação por e-mail e configure SMTP corporativo antes de cadastrar toda a equipe. Os cadastros ficam inativos até aprovação administrativa.
5. Em Project Settings > API Keys, copie a URL do projeto e a chave publishable (ou anon legada). A service_role é privada e será usada somente no servidor.

## 2. Publicar no GitHub e Vercel sem terminal

1. Extraia o ZIP. Crie um novo repositório privado, por exemplo `braveiros`, em https://github.com/new.
2. Envie o conteúdo da pasta extraída mantendo `src/`, `api/`, `public/`, `supabase/`, `tests/`, `index.html`, `package.json` e `vercel.json` na raiz. Não envie credenciais. Se o upload de pastas pelo navegador não preservar a estrutura, use Add file > Create new file e informe cada caminho, por exemplo `src/main.js`.
3. Na Vercel, Add New > Project > Import Git Repository. Selecione o repositório `braveiros`, framework Vite, build `npm run build`, output `dist`.
4. Cadastre as variáveis de ambiente de produção abaixo. As duas primeiras são necessárias para o login; a terceira e as variáveis privadas são necessárias para push.

| Variável | Valor |
|---|---|
| VITE_SUPABASE_URL | URL do novo projeto Supabase |
| VITE_SUPABASE_PUBLISHABLE_KEY | chave pública publishable/anon do novo projeto |
| VITE_BRAVADESK_URL | https://mktdesk.vercel.app (ou domínio atual) |
| VITE_VAPID_PUBLIC_KEY | chave pública VAPID exclusiva do Braveiros |
| SUPABASE_SERVICE_ROLE_KEY | service_role do novo projeto, nunca prefixar VITE_ |
| VAPID_PRIVATE_KEY | chave privada VAPID exclusiva do Braveiros |
| VAPID_SUBJECT | mailto:email institucional válido |
| CRON_SECRET | segredo aleatório exclusivo, mínimo 32 caracteres |

5. Deploy. Depois de obter o domínio de produção, no Supabase em Authentication > URL Configuration, defina Site URL e Redirect URLs com o domínio HTTPS do Braveiros. Faça redeploy após alterações em variáveis VITE_.

## 3. Criar o primeiro Super Admin

Cadastre-se no site, confirme o e-mail e use seu endereço real no SQL abaixo, APENAS no projeto Braveiros. O usuário será criado inicialmente inativo.

```sql
update public.profiles p
set role='super_admin', active=true
from auth.users u
where p.id=u.id and lower(u.email)=lower('SEU_EMAIL_INSTITUCIONAL');
```

Confirme que uma única linha foi afetada (ou consulte o perfil com o próprio e-mail no SQL Editor). Reabra o portal ou clique em Verificar novamente. Acesse Administração. Aprove novos cadastros após checar vínculo empregatício.

Perfis: employee (colaborador), admin (conteúdo e SAC/sugestões), ombudsman (somente atendimento da Ouvidoria, além dos módulos comuns), super_admin (administração e gestão de acessos). A Ouvidoria é confidencial identificada, não anônima. O super_admin não tem leitura direta de manifestações pela interface, porém operadores privilegiados do banco e responsáveis por provisionar perfis precisam ser considerados na governança institucional. Restrinja acessos ao Supabase e formalize retenção, exportação e descarte de dados com RH e responsáveis pela LGPD antes da produção.

## 4. Preencher módulos

Administração > Novo conteúdo > selecione o módulo. Rascunhos são privados para administradores; marcar Publicar torna conteúdo visível aos colaboradores ativos. Notícias e comunicados geram notificações internas e uma fila push por dispositivo, excluindo o autor. Títulos e descrições em texto simples; links devem ser HTTPS. Imagens usam links HTTPS autorizados; não coloque documentos confidenciais em links públicos.

- Transporte: um registro por linha, horário e ponto de embarque. Cadastre Norte 1, Norte 2, Sul 1 e Sul 2 se corresponderem à operação. Não inclui rastreamento GPS.
- Cursos: links de treinamentos e conclusão autodeclarada; não inclui prova, certificado ou plataforma de vídeo própria.
- Vagas: publicação e link de candidatura externa; não inclui recrutamento ou banco de currículos.
- Aniversariantes e reconhecimento: cadastro manual, com consentimento e política de privacidade. Não exponha ano de nascimento, telefone pessoal ou dados não necessários.
- Calendário: data, local e horário; visão mensal e listagem.
- Enquetes: opções uma por linha; uma resposta por usuário; resultados agregados para administradores. Não altere opções de uma enquete que já recebeu votos; publique outra.
- Achados e perdidos: colaborador envia relato; administração analisa em atendimentos e publica um item no módulo.
- SAC e sugestões: colaborador envia solicitação e acompanha status/resposta; administrador atende. Não há chat em tempo real ou anexos nesses módulos na v1.0.
- Ouvidoria: colaborador envia manifestação e acompanha resposta; apenas perfil ombudsman e autor ativo consultam pela aplicação. Não inclua detalhes de manifestações em notificações push.
- BravaDesk: botão externo, sem SSO ou compartilhamento de dados.
- Ramais e cartilha: catálogo gerenciado no painel.

## 5. Web Push

Use o gerador HTML offline do BravaDesk (uma cópia está no ZIP, fora da pasta public). Gere chaves novas, exclusivas do Braveiros, guarde-as com segurança e preencha a Vercel. Se trocar a chave, o botão Ativar notificações recria a inscrição quando identifica uma chave pública diferente. Abra o portal em HTTPS, Perfil > Ativar notificações. No iOS, instale o PWA na tela inicial e permita notificações. Os usuários precisam ativar por dispositivo. Ao sair da conta, o app tenta remover a inscrição no dispositivo para evitar notificações de outro usuário.

Ao publicar notícia/comunicado, o navegador chama `/api/push` usando o token do administrador. A função valida a conta pelo Supabase e busca entregas pendentes, com bloqueio de concorrência por registro, retentativas limitadas e descarte de inscrições expiradas. O conteúdo da notificação externa é genérico por privacidade. A aceitação pelo provedor não é garantia de visualização. Uma falha após aceite e antes de registrar envio pode ocasionar duplicidade; o tag ajuda navegadores compatíveis a agrupar.

Configure a contingência de cinco minutos no NOVO projeto Supabase:
- Integrations > Cron: habilite pg_cron e pg_net se ainda não estiverem ativos.
- Create job: nome `braveiros-push`, schedule `*/5 * * * *`, tipo HTTP Request, método POST.
- URL: `https://SEU-DOMINIO-BRAVEIROS.vercel.app/api/push`.
- Header Authorization: `Bearer ` seguido do CRON_SECRET da Vercel; Content-Type: application/json. Body: `{}`. Não publique o segredo nem envie prints dele.
- Se o projeto usa proteção de deployment da Vercel, utilize o domínio de produção acessível e configure bypass oficial se necessário. Não desative a autenticação da função.

Consulte o estado de fila com `supabase/diagnostico.sql`. `sent` indica aceitação pelo provedor, `pending` indica nova tentativa, `dead` falha permanente. Registros expirados, sem dispositivo ou de usuários desativados não são enviados. O máximo por rodada é 30; grandes públicos podem receber em lotes, não todos instantaneamente. Configure uma rotina de retenção de fila/notificações em produção. Não há painel de gestão de push além do diagnóstico SQL.

## 6. PWA e tema

No Perfil há botão Instalar aplicativo (quando suportado) e Alternar tema. No Safari/iOS use Compartilhar > Adicionar à Tela de Início. O manifest e o service worker estão incluídos. PWA instalável não significa que os dados funcionam offline; o portal precisa de conexão e não guarda conteúdo privado em cache offline.

## 7. Homologação obrigatória

- Criar duas contas de colaborador e uma conta administrativa; confirmar e aprovar.
- Testar cadastro inativo, login, recuperação de senha, revogação de acesso e logout.
- Confirmar que colaborador A não lê solicitação B, voto B ou notificações B, nem altera seu próprio perfil/role; testar com consultas REST autenticadas, não com SQL Editor (que possui privilégios elevados).
- Confirmar que admin comum e super_admin não leem Ouvidoria pelo cliente, e que o perfil ombudsman não administra conteúdos nem recebe SAC de terceiros.
- Publicar e editar cada módulo, testar formulário de SAC, sugestões, achados, enquetes, progresso, calendário, carrossel com dois avisos, validade e navegação.
- Testar desktop e mobile, modo escuro, teclado, instalação PWA e push em outra conta com app fechado.
- Verificar HTTP 200 do Cron, resultados sent/failed e logs Vercel (não compartilhar credenciais).
- Fazer backup e definir políticas de retenção e auditoria de acessos antes de armazenar manifestações reais.

## Estado da entrega

Implementação inicial para homologação, não sistema de produção certificado. Sintaxe JavaScript verificada por Node e cinco testes isolados aprovados (`npm test`). Não foi possível instalar dependências no cache npm deste ambiente; portanto build Vite, SQL em PostgreSQL real, testes de RLS, testes visuais e envio real de push permanecem pendentes. Não foi realizada publicação em GitHub, Vercel ou Supabase. A lista de conteúdo está limitada a 500 publicações/solicitações e 100 notificações por consulta; gestão de colaboradores até 1000 registros. Ainda não há busca/paginação abrangente, administração por departamento, SSO, upload de documentos, auditoria completa, relatórios avançados ou segmentação de comunicados. O curso é um catálogo com progresso simples, e a Ouvidoria não substitui canal institucional regulamentado. Nenhum dado real foi pré-cadastrado.

## Atualização 1.0.1

Correção das inscrições Realtime em src/main.js. Para instalações existentes, não execute novamente o SQL; preserve as variáveis de ambiente. Atualize os arquivos e confirme o deploy.
