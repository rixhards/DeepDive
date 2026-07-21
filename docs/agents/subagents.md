# Subagents — DarkDive

> Define os subagentes especializados invocados pelo Orchestrator.

## O que é um Subagent

Um subagente é um agente filho com escopo restrito, invocado por um agente pai para executar uma tarefa específica de forma autônoma.

---

## Subagent: spec-validator

**Invocado por:** Orchestrator
**Responsabilidade:** <!-- TODO: Validar se uma spec está completa e bem formada -->
**Input:** <!-- TODO: path do arquivo de spec -->
**Output:** <!-- TODO: lista de itens faltando ou "VALID" -->
**Condição de retorno:** <!-- TODO: quando terminar a análise -->

---

## Subagent: file-scaffolder

**Invocado por:** Code Generator
**Responsabilidade:** <!-- TODO: Criar estrutura de arquivos a partir de uma spec -->
**Input:** <!-- TODO -->
**Output:** <!-- TODO -->

---

## Subagent: test-runner

**Invocado por:** QA / Harness
**Responsabilidade:** <!-- TODO: Executar testes e coletar resultados -->
**Input:** <!-- TODO -->
**Output:** <!-- TODO -->

---

## Subagent: rag-retriever

**Invocado por:** Qualquer agente
**Responsabilidade:** <!-- TODO: Buscar contexto relevante no RAG -->
**Input:** <!-- TODO: query -->
**Output:** <!-- TODO: chunks relevantes -->

---

## Como Criar um Subagent

1. Definir responsabilidade única (single responsibility)
2. Documentar inputs, outputs e condição de retorno
3. Adicionar entrada neste arquivo
4. Implementar a invocação no agente pai
