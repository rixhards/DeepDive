# Workflows — DarkDive

> Fluxos de trabalho orquestrados que combinam agentes, skills e ferramentas.

## Workflow: Spec → Código → Review → Deploy

```
[PRD / Ideia]
     ↓
[Spec Writer Agent] → gera docs/specs/NNN-feature.md
     ↓
[Human Review] → aprova spec
     ↓
[Code Generator Agent] → implementa código
     ↓
[Reviewer Agent] → revisa contra spec
     ↓
[QA / Harness Agent] → executa testes
     ↓
[Deploy]
```

<!-- TODO: Detalhar cada etapa, condições de parada, handoffs -->

---

## Workflow: Onboarding de Novo Agente

<!-- TODO: Como adicionar um novo agente ao sistema -->

---

## Workflow: Debug com IA

<!-- TODO: Fluxo para usar agentes na investigação de bugs -->

---

## Condições de Parada (Stop Conditions)

<!-- TODO: Quando um workflow deve parar e aguardar input humano -->

## Retry e Error Handling

<!-- TODO: Como lidar com falhas em cada etapa -->
