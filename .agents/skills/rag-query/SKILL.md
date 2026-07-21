---
name: rag-query
description: Consulta a base de conhecimento do projeto (RAG) para recuperar contexto relevante. Use quando precisar de informações sobre specs existentes, decisões arquiteturais ou código do projeto.
---

# Skill: rag-query

## Responsabilidade

Buscar e retornar trechos relevantes da base de conhecimento indexada do projeto para enriquecer o contexto de outros agentes.

## Inputs

- `query`: Pergunta ou descrição do contexto necessário em linguagem natural
- `top_k`: Número de resultados a retornar (padrão: 5)
- `source_filter`: Opcional — filtrar por tipo de fonte (`specs`, `adr`, `code`, `docs`)

## Processo

1. Transformar a `query` em embedding
2. Buscar no vector store os `top_k` chunks mais similares
3. Aplicar `source_filter` se fornecido
4. Retornar os chunks com metadados (fonte, score, contexto)

## Outputs

```
[
  {
    "source": "docs/specs/001-chat-ui.md",
    "score": 0.92,
    "content": "..."
  },
  ...
]
```

## Quando Usar

- Antes de gerar uma nova spec (verificar specs existentes)
- Antes de gerar código (verificar padrões existentes)
- Antes de uma revisão (verificar decisões anteriores)
- Quando um agente precisar de contexto do domínio

## Configuração

Ver `docs/rag/rag.md` para detalhes de configuração da base de conhecimento.
