# Braveiros 1.1.0 | Social Experience

Portal interno dos colaboradores do Cana Brava Resort. Identidade visual neutra, com temas claro/escuro legíveis, feed social, Stories e carrossel de mídia.

## Capacidades

- Feed interno com publicações exclusivas de Admin/Super Admin, curtidas, comentários, compartilhamento e carrossel de até 10 mídias.
- Stories (imagem/vídeo) com expiração de 24 horas e visualização por departamento.
- Cadastro por matrícula, aprovação administrativa, gerenciamento de departamentos, cargos e colaboradores.
- Serviços existentes: ônibus, treinamentos, cartilha, eventos, SAC, Ouvidoria, notificações, vagas e mais.
- Interface adaptável a celular e desktop, PWA e modo escuro.

## Instalação / atualização

**Leia `ATUALIZACAO-V110.md`.** Para atualizar a v1.0.9, execute `supabase/v110.sql` após backup e envie os arquivos do pacote de atualização para as pastas correspondentes na branch `main`.

```bash
npm install
npm test
npm run build
```

Variáveis de ambiente e configurações do Supabase são preservadas. Nunca envie o arquivo `.env` ou a chave `SUPABASE_SERVICE_ROLE_KEY` ao GitHub.
