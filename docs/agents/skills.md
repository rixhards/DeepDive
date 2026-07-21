# Skills — DarkDive

> Catálogo de skills reutilizáveis disponíveis para os agentes.

## O que é uma Skill

Uma skill é uma capacidade atômica e reutilizável que um agente pode invocar.
Cada skill tem: nome, descrição, inputs, outputs, e como ativá-la.

---

## Skill: generate-spec

**Descrição:** <!-- TODO: Gera um arquivo de spec a partir de um PRD ou prompt -->
**Trigger:** <!-- TODO: quando o agente recebe um pedido de nova feature -->
**Inputs:** <!-- TODO: PRD, contexto do produto -->
**Outputs:** <!-- TODO: arquivo .md em docs/specs/ -->
**Arquivo:** `.agents/skills/generate-spec/SKILL.md`

---

## Skill: run-tests

**Descrição:** <!-- TODO: Executa a suíte de testes e retorna relatório -->
**Trigger:** <!-- TODO: após geração de código -->
**Inputs:** <!-- TODO -->
**Outputs:** <!-- TODO: resultado dos testes -->
**Arquivo:** `.agents/skills/run-tests/SKILL.md`

---

## Skill: code-review

**Descrição:** <!-- TODO: Revisa código contra uma spec aprovada -->
**Trigger:** <!-- TODO: após PR criado -->
**Inputs:** <!-- TODO -->
**Outputs:** <!-- TODO -->
**Arquivo:** `.agents/skills/code-review/SKILL.md`

---

## Skill: rag-query

**Descrição:** <!-- TODO: Consulta o RAG com contexto do projeto -->
**Trigger:** <!-- TODO: quando agente precisa de contexto adicional -->
**Inputs:** <!-- TODO: query em linguagem natural -->
**Outputs:** <!-- TODO: trechos relevantes da base de conhecimento -->
**Arquivo:** `.agents/skills/rag-query/SKILL.md`

---

## Como Adicionar uma Nova Skill

1. Criar pasta em `.agents/skills/<nome-da-skill>/`
2. Criar arquivo `SKILL.md` com frontmatter YAML (`name`, `description`)
3. Adicionar entrada neste catálogo
