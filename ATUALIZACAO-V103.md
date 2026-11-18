# Braveiros 1.0.3 | Employee Identity

## Atualização de um projeto existente (1.0.2)
1. Faça backup do banco Braveiros e teste em homologação. Não use o Supabase do BravaDesk.
2. Execute todo `supabase/v103.sql` no SQL Editor. Não execute novamente `install.sql` no banco existente.
3. Em Authentication > Sign In / Providers > Email, mantenha o provedor habilitado e desative Confirm email. Mantenha cadastro habilitado. Não envie e-mails para identificadores sintéticos. Desabilite fluxos de recuperação por e-mail no portal (já removidos da interface). 
4. Atualize os arquivos GitHub utilizando o ZIP de atualização, ou o projeto completo. As variáveis existentes bastam, incluindo SUPABASE_SERVICE_ROLE_KEY (somente servidor) e VITE_SUPABASE_PUBLISHABLE_KEY. Confirme deploy de produção Ready e atualize a página.
5. Recupere o primeiro administrador existente pelo SQL abaixo. O script v103 cria perfis ausentes com active=false, sem promover contas automaticamente. Verifique a identidade da conta antes de promover.

```sql
UPDATE public.profiles p SET role='super_admin', active=true
FROM auth.users u WHERE p.id=u.id AND lower(u.email)=lower('SEU_EMAIL_INSTITUCIONAL')
RETURNING p.id,p.role,p.active;
```
Entre com o e-mail antigo e senha existente. Se a senha estiver incorreta, use o recurso administrativo de recuperação da conta real pelo Supabase Auth (ou redefinição pelo e-mail real via fluxo de recuperação já existente no Auth). Nenhum SQL desta versão altera a senha antiga.

## Instalação nova
Execute `supabase/install.sql` uma única vez e depois `supabase/v103.sql`. Para o primeiro Super Admin, antes de executar v103, crie o usuário pelo painel Authentication com e-mail real, confirme-o e execute o UPDATE acima. Depois execute v103. Alternativamente, após a migração, como operador do banco, insira uma matrícula autorizada em br_employees, cadastre-se pelo portal e promova o perfil exato, após verificar a identidade. Nunca promova uma conta desconhecida.

## Cadastro e aprovação
Administração > Gestão de colaboradores > Matrículas autorizadas. Importe CSV UTF-8 com cabeçalho `matricula;nome;departamento`. Máximo 500 linhas por importação; o modelo contém exemplo, substitua pelos registros oficiais. Formate matrícula como texto no Excel para preservar zeros à esquerda. Arquivos com vírgula também são aceitos. Registros existentes têm nome/departamento atualizados; matrículas bloqueadas permanecem bloqueadas. A lista visível é limitada a 1000 registros por consulta.
O colaborador informa matrícula e senha (mínimo 8 caracteres), e-mail de contato opcional. O banco verifica a matrícula autorizada e usa nome/departamento oficiais. O identificador interno é um e-mail sintético reservado, não uma caixa postal. O acesso permanece pendente até o Super Admin verificar presencialmente a identidade e marcar Ativo. Uma matrícula conhecida por terceiros pode ser reivindicada antes do titular; a aprovação humana é indispensável. Não use matrícula como senha.

Para contas antigas, importe a matrícula e use Vincular matrícula no perfil correspondente. O vínculo não altera a conta Auth ou histórico; a mesma senha funciona por matrícula, ou pelo e-mail legado. O login por matrícula passa por /api/identity, que resolve o identificador no servidor. Não se divulga o e-mail associado. Não é possível trocar matrícula já vinculada pela interface nesta versão; correção excepcional deve ser feita pelo operador após conferência.

## Senha sem e-mail
O colaborador solicita redefinição presencialmente ao RH/administração. Super Admin verifica a identidade e usa Redefinir senha no perfil. O servidor gera uma senha temporária aleatória; copie e entregue reservadamente. No próximo login, a pessoa precisa definir nova senha (12 caracteres ou mais). O acesso aos módulos fica bloqueado até a troca. Sessões anteriores ao reset são bloqueadas pelas regras br_role; não há remoção física de todos os tokens Auth. A função de reset não permite redefinir outro Super Admin nem a própria conta. O bloqueio de matrícula desativa o perfil e remove dispositivos push cadastrados; reativar matrícula exige aprovar novamente o perfil. A interface legada de aprovação de usuários sem matrícula permanece disponível para a migração de contas antigas. 

## Homologação indispensável
Testar cadastro autorizado e não autorizado, duplicidade, perfil pendente, aprovação, login por matrícula, vínculo de conta antiga, bloqueio/reativação, reset e troca obrigatória, acesso usando sessão anterior ao reset, Ouvidoria confidencial e push. Configure limites de autenticação e proteção contra abuso (especialmente se publicar na internet); esta versão não inclui rate limiting por IP próprio, CAPTCHA ou validação de identidade automática. O login por matrícula usa a API Auth do Supabase, sujeita a seus limites, inclusive IP compartilhado do backend. O reset envolve duas operações (perfil e Auth); em falha parcial, repita o reset pelo Super Admin. Não libere para todos antes dos testes reais. Não envie CSV com colaboradores ou credenciais ao GitHub.

## Validação local
11 testes Node passaram; sintaxe JS verificada. Não foi executada migração em PostgreSQL real nem build Vite com dependências instaladas. Testes de autorização e entrega push em produção continuam pendentes. 
