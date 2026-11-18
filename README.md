# Braveiros 1.0.6

Revisão do código enviado pelo usuário. Entrada separada, proteção contra eventos repetidos e falhas de inicialização, diagnóstico de matrículas sem interromper o portal inteiro.

## Publicação
Extraia o projeto; envie o conteúdo da pasta raiz ao repositório correto. Na Vercel: Vite, npm run build, dist. Preserve todas as variáveis atuais; não envie .env. Não é necessário executar SQL se a migração v103 já estiver aplicada. O SQL existente é mantido para referência.

## Fotos
Adicione public/onboarding/slide-01.jpg, slide-02.jpg, slide-03.jpg (1080 × 1920 sugerido). Até lá, gradiente de fundo.

## Diagnóstico
Console: Braveiros 1.0.6 | Entrada revisada. O build não minifica para facilitar inspeção. Testes simulados não substituem deploy e Supabase real.

## Limites
Não é possível saber se uma pessoa deslogada tem conta ativa antes de identificar sua matrícula; usamos o histórico local da apresentação. Não alteramos RLS ou API de identidade.
