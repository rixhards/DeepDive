# DarkDive — Índice de Documentação SDD

> Este projeto usa **Spec-Driven Development (SDD)** com IA.
> Toda feature começa em uma spec aprovada antes de qualquer linha de código.

---

## 🧭 Navegação Rápida

| Documento | Propósito |
|-----------|-----------|
| [AGENTS.md](./AGENTS.md) | Regras globais para todos os agentes de IA |
| [docs/vision.md](./docs/vision.md) | Visão de alto nível do produto |
| [docs/architecture.md](./docs/architecture.md) | Arquitetura técnica e decisões |

---

## 📋 Specs

> Toda feature deve ter uma spec aprovada antes de ser implementada.

| Nº | Spec | Status |
|----|------|--------|
| 001 | [Chat UI](./docs/specs/001-chat-ui.md) | `draft` |
| — | [Template para novas specs](./docs/specs/_template.md) | — |

---

## 🤖 Agentes & IA

| Documento | Propósito |
|-----------|-----------|
| [Agents](./docs/agents/agents.md) | Catálogo de agentes |
| [Skills](./docs/agents/skills.md) | Skills reutilizáveis |
| [Subagents](./docs/agents/subagents.md) | Subagentes especializados |
| [Workflows](./docs/agents/workflows.md) | Fluxos orquestrados |

---

## 🔧 Infraestrutura de IA

| Documento | Propósito |
|-----------|-----------|
| [MCP](./docs/mcp/mcp.md) | Model Context Protocol |
| [RAG](./docs/rag/rag.md) | Retrieval-Augmented Generation |
| [Harness](./docs/harness/harness.md) | Testes e validação |
| [Progressive Disclosure](./docs/progressive-disclosure/progressive-disclosure.md) | Contexto em camadas |
| [Plugins](./docs/plugins/plugins.md) | Extensões do sistema |
| [Hooks](./docs/hooks/hooks.md) | Pontos de extensão do ciclo de vida |

---

## 📐 Decisões Arquiteturais (ADRs)

| ADR | Título | Status |
|-----|--------|--------|
| [ADR-001](./docs/adr/ADR-001-template.md) | Template | — |

---

## 🚀 Como Contribuir

1. **Nova feature?** → Criar spec em `docs/specs/` usando o template
2. **Spec aprovada?** → Claude Code via terminal implementa
3. **Código gerado?** → Claude Sonnet no Antigravity revisa contra a spec
4. **Decisão importante?** → Criar ADR em `docs/adr/`

---

## 🛠️ Skills Disponíveis (.agents/skills/)

| Skill | Descrição |
|-------|-----------|
| [generate-spec](./.agents/skills/generate-spec/SKILL.md) | Gera specs a partir de PRDs |
| [code-review](./.agents/skills/code-review/SKILL.md) | Revisa código contra specs |
| [rag-query](./.agents/skills/rag-query/SKILL.md) | Consulta base de conhecimento |
