---
name: generate-spec
description: Gera um arquivo de spec SDD completo a partir de um PRD, ideia ou prompt do usuário. Use quando o usuário pedir uma nova feature e precisar de uma spec estruturada em docs/specs/.
---

# Skill: generate-spec

## Responsabilidade

Criar um arquivo `.md` de spec no padrão SDD em `docs/specs/NNN-feature-name.md`, com todas as seções necessárias preenchidas a partir do input fornecido.

## Inputs

- `feature_description`: Descrição da feature em linguagem natural
- `spec_number`: Número sequencial da spec (ex: `002`)
- `feature_slug`: Slug para o nome do arquivo (ex: `inventory-system`)

## Processo

1. Ler o template de spec em `docs/specs/_template.md` (se existir)
2. Consultar specs existentes em `docs/specs/` para manter consistência
3. Consultar `docs/vision.md` para alinhar com objetivos do produto
4. Gerar a spec com todas as seções preenchidas
5. Salvar em `docs/specs/NNN-feature-slug.md`
6. Reportar o path do arquivo criado

## Outputs

- Arquivo `.md` criado em `docs/specs/`
- Confirmação com path e resumo do conteúdo gerado

## Critérios de Qualidade

- Todos os critérios de aceite devem ser verificáveis (não vagos)
- Casos de borda devem estar listados
- Status inicial: `draft`
- Nenhuma seção TODO deve ficar vazia sem justificativa

## Exemplo de Uso

```
Input: "Quero adicionar um sistema de inventário onde o jogador coleta itens"
Output: docs/specs/002-inventory-system.md
```
