# Braveiros 1.0.7 | Social & People

## Atualizar o projeto existente (sem terminal)
1. Faça backup do banco e do repositório atual. Guarde o commit da versão 1.0.6.
2. No Supabase do **Braveiros**, SQL Editor → New query, cole `supabase/v107.sql` e execute. É uma migração aditiva, não recria tabelas antigas. Não execute install.sql nem v103.sql novamente. Se falhar, copie a mensagem e não publique a versão nova.
3. Descompacte o ZIP de atualização. No GitHub, branch main, substitua os arquivos nas mesmas pastas (não envie o ZIP nem uma pasta externa). Em `src/`, substitua main.js, style.css, identity.js. Em `tests/`, substitua startup.test.js e identity.test.js. Em `supabase/`, adicione v107.sql. Na raiz, substitua package.json e adicione este guia. O modelo CSV é opcional: está em public/modelo-colaboradores-v107.csv.
4. Preserve suas imagens de onboarding, variáveis da Vercel, logo e demais arquivos. Não desconecte o repositório.
5. Verifique o novo deployment na Vercel. Se necessário, use o Deploy Hook da branch main que funcionou na atualização anterior. Confira o commit e `braveiros@1.0.7 build` nos logs. Não faça redeploy de um commit antigo.
6. Teste primeiro com Super Admin, depois Admin e Colaborador de teste. Se necessário, volte o deployment à versão 1.0.6; a migração aditiva pode permanecer, mas as políticas novas de audiência continuarão ativas.

## Usar
- Feed inicial: notícias e comunicados existentes aparecem automaticamente, conforme o acesso. Curtidas únicas por conta, comentários, compartilhamento por URL autenticada e visualizações únicas pela exposição do card. A contagem é atualizada ao recarregar os dados.
- Admin e Super Admin: botão Publicar; até 10 mídias por publicação (JPEG/PNG/WebP/MP4/WebM), cada arquivo até 50 MB, sujeito aos limites do Storage do projeto. Compartilhamentos não tornam o conteúdo público. Links assinados expiram em dez minutos. Admins podem editar/moderar publicações institucionais, inclusive de outros admins, conforme a permissão já existente da v1.0.6.
- Agendamento: o horário é interpretado como Bahia (UTC-3). Publicações vencidas são liberadas quando uma sessão ativa atualiza o feed. Para execução independente de usuários, configure Supabase Cron (se disponível) com `select public.br_publish_due();` a cada minuto. A notificação interna entra na fila na publicação; push de conteúdos agendados depende também do processamento recorrente da fila /api/push que já existe no projeto. Não foi instalado cron automaticamente.
- Super Admin: Administração continua disponível; Pessoas e departamentos permite cadastrar/renomear/desativar setores e cargos, editar nome, função, setor, permissão e status de outros colaboradores. O próprio acesso Super Admin não pode ser removido pelo próprio usuário. Cargos profissionais não concedem permissão de sistema. Os departamentos existentes são importados sem alterar os nomes. Departamentos sem nome devem ser atribuídos manualmente.
- CSV: modelo antigo (matricula,nome,departamento) continua válido. O novo adiciona cargo. Preserve zeros à esquerda. Cadastro continua sujeito à aprovação.
- Perfil: foto, cargo, departamento, cursos concluídos e preferências. O menu inferior no celular oferece Feed, Ônibus, Serviços, Avisos e Perfil; opções administrativas também ficam em Serviços e Perfil. Todos os módulos anteriores continuam acessíveis.
- Mídias removidas de posts deixam de ter leitura para colaboradores, mas não são apagadas fisicamente; manutenção de arquivos órfãos pelo Storage é necessária. Fotos de perfil são visíveis a usuários ativos. Não publique imagens sensíveis.

## Validação manual antes de produção
- Primeiro acesso, login, cadastro, aprovação, logout, recuperação, Super Admin e Ouvidoria.
- Criar publicação como admin, enviar imagem e vídeo, carrossel, curtir/descurtir, comentar, compartilhar e abrir link em outra conta, moderar comentário.
- Criar departamento e cargo, editar terceiro, testar bloqueio de alteração do próprio papel, verificar histórico e CSV.
- Publicação para departamento A não pode aparecer para colaborador B; testar acesso ao link, API e Storage com ambas as contas. Testar agendamento e envio de push.
- Conferir navegação móvel, desktop, modo escuro e os módulos antigos.

## Limites da validação local
Testes Node com banco simulado e validação de sintaxe. Não houve acesso ao Supabase real, navegador móvel ou Vercel. O build completo depende da instalação do Vite e dependências. O SQL não foi executado neste ambiente. O pacote deve ser validado em ambiente de teste antes de produção.
