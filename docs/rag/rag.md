# RAG (Retrieval-Augmented Generation) — DarkDive

> Estratégia de recuperação de contexto para enriquecer as respostas dos agentes.

## Objetivo

<!-- TODO: Por que usamos RAG neste projeto? Qual contexto precisa ser recuperado? -->

## Fontes de Conhecimento (Knowledge Sources)

| Fonte | Tipo | Frequência de Indexação | Descrição |
|-------|------|------------------------|-----------|
| `docs/specs/` | Markdown | A cada commit | Specs do produto |
| `docs/architecture.md` | Markdown | Manual | Decisões arquiteturais |
| Codebase Swift | Código | A cada commit | Implementações existentes |
| <!-- TODO --> | | | |

## Estratégia de Chunking

<!-- TODO: Como os documentos são divididos em chunks? Tamanho, overlap, etc. -->

## Embeddings

**Modelo:** <!-- TODO: ex. text-embedding-3-small -->
**Dimensão:** <!-- TODO -->
**Provedor:** <!-- TODO -->

## Vector Store

**Tipo:** <!-- TODO: ex. local (FAISS), cloud (Pinecone), etc. -->
**Config:** <!-- TODO -->

## Retrieval

**Top-K:** <!-- TODO: quantos chunks recuperar por query -->
**Threshold de relevância:** <!-- TODO -->
**Estratégia de reranking:** <!-- TODO -->

## Integração com Agentes

<!-- TODO: Como os agentes invocam o RAG (via skill, via MCP, direto?) -->

## Atualização da Base

<!-- TODO: Processo de re-indexação quando docs mudam -->
