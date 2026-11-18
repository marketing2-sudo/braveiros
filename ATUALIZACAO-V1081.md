# Braveiros 1.0.8.1 — Cadastro com aprovação administrativa
Pré-requisito: v1.0.8 instalada, inclusive SQL. Faça backup do banco e do repositório antes de atualizar.
1. Supabase SQL Editor: execute integralmente supabase/v1081.sql. Não execute as migrações antigas novamente.
2. GitHub: substitua api/identity.js, src/main.js e package.json com os arquivos do pacote. Os testes e a migração também podem ser copiados nas respectivas pastas. Preserve imagens e personalizações.
3. Acione o Deploy Hook da branch main usado anteriormente. Confirme braveiros@1.0.8.1 build nos logs.
4. Cadastre uma matrícula nova com nome, departamento, senha e e-mail opcional. Entre com matrícula e senha e veja a tela Aguardando liberação. Em outra sessão, entre como Admin/Super Admin e acesse Administração > Solicitações de cadastro > Atualizar. Confira os dados com RH e aprove ou recuse. Verifique se somente após aprovação o novo usuário acessa o conteúdo.
A matrícula continua sendo identificador de login; zeros à esquerda são preservados (2323 e 002323 são identificadores diferentes). A lista histórica br_employees não é apagada, mas não é exigida para login, autorização ou cadastro. A interface de importação foi removida. Ativação é controlada por profiles.active. Nome e departamento são autodeclarados até revisão. Não compartilhe a chave service_role; mantenha as variáveis da v1.0.8.
Testes locais JS com mocks; SQL e build Vite não executados neste ambiente. Configure limitação de requisições para /api/identity antes de divulgar o portal.
