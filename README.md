# Braveiros 1.0.9

Portal interno para a equipe do Cana Brava Resort.

## Recursos

- Feed social com publicações de Admin/Super Admin, curtidas, comentários e compartilhamento interno.
- Sidebar no desktop e barra de navegação inferior no celular.
- Login por matrícula e aprovação administrativa de novos cadastros.
- Gestão de colaboradores, departamentos, cargos e permissões pelo Super Admin.
- Notícias, comunicados, ônibus, cursos, cartilha, aniversariantes, eventos, SAC, Ouvidoria, sugestões, vagas e outros serviços.
- Notificações web push, perfil, modo escuro e PWA.

## Publicar

Leia **ATUALIZACAO-V109.md** antes de alterar o sistema existente. Preserve o Supabase, as variáveis da Vercel e todos os arquivos de mídia. Execute a migração `supabase/v109.sql` antes de publicar o código atualizado.

## Desenvolvimento

```bash
npm install
npm test
npm run build
```

Variáveis em `.env.example`. Nunca publique a chave de serviço do Supabase em código acessível pelo navegador.

## Segurança

Os privilégios são determinados pelo Supabase e não apenas pelos botões visíveis. Cadastros públicos permanecem pendentes até aprovação do Admin ou Super Admin. A confirmação de identidade com o RH continua necessária antes de aprovar uma conta.

## Limitações

O pacote foi validado com testes automatizados e renderização de prévia com dados fictícios. O build do Vite depende de `npm install`; a execução completa no Supabase e na Vercel requer validação no ambiente real.
