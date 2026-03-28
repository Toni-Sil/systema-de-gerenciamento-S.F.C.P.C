# Contribuindo com o S.F.C.P.C

Obrigado por considerar contribuir! Siga estas diretrizes:

## Fluxo de Trabalho

1. Fork o repositório
2. Crie uma branch a partir de `main`:
   ```bash
   git checkout -b feat/sua-feature
   # ou
   git checkout -b fix/seu-bugfix
   ```
3. Desenvolva sua feature
4. Rode os testes:
   ```bash
   # Backend
   pytest tests/ -v --cov=src

   # Frontend
   cd frontend && npm test
   ```
5. Commit usando [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat: adiciona exportação CSV de movimentações
   fix: corrige cálculo de ROI no dashboard
   refactor: reorganiza serviço de estoque
   docs: atualiza README com novos endpoints
   ```
6. Abra um Pull Request descrevendo o que foi feito

## Padrões de Código

### Backend (Python)
- Linting: `ruff check src/ tests/`
- Formatação: `ruff format src/ tests/`
- Tipagem: `mypy src/ --ignore-missing-imports`

### Frontend (TypeScript)
- Linting: `npm run lint`
- Sem `any` explícito — use tipos definidos
- Componentes devem ter props tipadas

## Estrutura de Commits

| Prefixo | Uso |
|---------|-----|
| `feat:` | Nova funcionalidade |
| `fix:` | Correção de bug |
| `refactor:` | Refatoração sem mudar comportamento |
| `docs:` | Documentação |
| `test:` | Adiciona ou corrige testes |
| `ci:` | Pipelines e workflows |
| `chore:` | Tarefas de manutenção |
