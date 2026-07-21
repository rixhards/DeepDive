---
name: code-review
description: Revisa o código implementado verificando conformidade com a spec aprovada. Use após a geração de código pelo Code Generator para garantir que a implementação atende aos critérios de aceite.
---

# Skill: code-review

## Responsabilidade

Comparar o código implementado contra a spec aprovada em `docs/specs/` e produzir um relatório de conformidade.

## Inputs

- `spec_path`: Path da spec que foi implementada
- `files_changed`: Lista de arquivos criados/modificados

## Processo

1. Ler a spec em `spec_path`
2. Extrair os critérios de aceite da spec
3. Examinar cada arquivo em `files_changed`
4. Para cada critério de aceite, verificar se está coberto pelo código
5. Identificar divergências, code smells, e itens faltando
6. Gerar relatório

## Outputs

- Relatório de revisão com:
  - ✅ Critérios atendidos
  - ❌ Critérios não atendidos
  - ⚠️ Possíveis problemas
  - 💡 Sugestões de melhoria

## Critérios de Aprovação

- Todos os critérios de aceite marcados como ✅
- Sem ❌ (bloqueadores)
- ⚠️ podem ser aceitos com justificativa documentada
