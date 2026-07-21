# Agents — DarkDive

> Define os agentes de IA utilizados no projeto, suas responsabilidades e como se comunicam.

## Agente: Orchestrator

**Modelo:** <!-- TODO: ex. Claude Sonnet 4.6 via Antigravity -->
**Responsabilidade:** <!-- TODO: coordenar outros agentes -->
**Inputs:** <!-- TODO: O que recebe -->
**Outputs:** <!-- TODO: O que produz -->
**Handoffs:** <!-- TODO: Quando delega para qual agente -->

---

## Agente: Spec Writer

**Modelo:** <!-- TODO -->
**Responsabilidade:** <!-- TODO: Gerar e refinar specs a partir de PRDs -->
**Inputs:** <!-- TODO -->
**Outputs:** <!-- TODO: arquivos em docs/specs/ -->

---

## Agente: Code Generator

**Modelo:** <!-- TODO: Claude Code via terminal -->
**Responsabilidade:** <!-- TODO: Implementar código a partir de specs aprovadas -->
**Inputs:** <!-- TODO: spec aprovada + contexto do codebase -->
**Outputs:** <!-- TODO: pull requests / commits -->

---

## Agente: Reviewer

**Modelo:** <!-- TODO -->
**Responsabilidade:** <!-- TODO: Revisar código gerado contra a spec -->
**Inputs:** <!-- TODO -->
**Outputs:** <!-- TODO: aprovação ou lista de ajustes -->

---

## Agente: QA / Harness

**Modelo:** <!-- TODO -->
**Responsabilidade:** <!-- TODO: Executar testes e validar critérios de aceite -->
**Inputs:** <!-- TODO -->
**Outputs:** <!-- TODO: relatório de testes -->

---

## Diagrama de Colaboração

<!-- TODO: Mermaid diagram mostrando fluxo entre agentes -->
