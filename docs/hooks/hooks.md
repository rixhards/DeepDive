# Hooks — DarkDive

> Pontos de extensão do ciclo de vida do sistema para agentes e aplicação.

## O que são Hooks

Hooks são pontos de interceptação definidos no ciclo de vida do sistema onde agentes ou módulos externos podem executar lógica personalizada sem modificar o fluxo principal.

---

## Hooks do Ciclo de Vida dos Agentes

### `before_spec_approved`
**Quando dispara:** Antes de uma spec ser marcada como `approved`
**Payload:** `{ spec_path, spec_content, reviewer }`
**Uso:** <!-- TODO: ex. validação automática de completude -->

---

### `after_code_generated`
**Quando dispara:** Após o Code Generator produzir código
**Payload:** `{ spec_path, files_created, files_modified }`
**Uso:** <!-- TODO: ex. executar linter, formatar código -->

---

### `before_test_run`
**Quando dispara:** Antes do Harness executar testes
**Payload:** `{ test_suite, target_files }`
**Uso:** <!-- TODO: ex. setup de ambiente, mocks -->

---

### `after_test_run`
**Quando dispara:** Após execução dos testes
**Payload:** `{ results, coverage, failures }`
**Uso:** <!-- TODO: ex. notificação, atualização de status da spec -->

---

## Hooks da Aplicação

### `onSceneLoad`
<!-- TODO: Hook disparado quando uma cena do DarkDive é carregada -->

### `onPuzzleSolved`
<!-- TODO: Hook disparado quando um puzzle é resolvido -->

---

## Como Implementar um Hook

1. Definir o hook neste documento
2. Implementar o ponto de disparo no código
3. Documentar o payload e contratos esperados
