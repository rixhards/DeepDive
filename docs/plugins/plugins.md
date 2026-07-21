# Plugins — DarkDive

> Catálogo de plugins que estendem as capacidades dos agentes e da aplicação.

## O que é um Plugin neste Projeto

Um plugin é um módulo autocontido que adiciona capacidades ao sistema sem modificar o núcleo. Pode ser um plugin para um agente (ex: ferramenta de busca), para a aplicação (ex: módulo de analytics), ou para o ambiente de desenvolvimento.

---

## Plugin: [Nome do Plugin]

**Tipo:** `agent` | `application` | `dev-tool`
**Responsabilidade:** <!-- TODO -->
**Ativado quando:** <!-- TODO -->
**Configuração:** <!-- TODO -->
**Arquivo:** `docs/plugins/<nome>/plugin.md`

---

## Estrutura de um Plugin

```
docs/plugins/<nome>/
  plugin.md        # Descrição e configuração
  SKILL.md         # Se o plugin expõe uma skill a agentes
  config.json      # Configuração do plugin (se necessário)
```

## Como Adicionar um Plugin

1. Criar pasta em `docs/plugins/<nome>/`
2. Criar `plugin.md` com descrição, tipo e configuração
3. Se expõe skills, criar `SKILL.md`
4. Registrar neste catálogo

## Plugins Ativos

| Plugin | Tipo | Status | Descrição |
|--------|------|--------|-----------|
| <!-- TODO --> | | | |
