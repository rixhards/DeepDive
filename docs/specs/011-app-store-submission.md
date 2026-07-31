# Spec 011 — Submissão à App Store

## Status
`implemented` (código e conteúdo) · pendente das etapas manuais da seção "O que só o Richard pode fazer"

## Contexto

O jogo está completo e estável, mas nunca passou por uma preparação de distribuição. Um
projeto que compila e roda no device não é um projeto submissível: falta declaração de
compliance, faltam URLs públicas obrigatórias, falta conteúdo de listagem e falta o
certificado de distribuição.

Esta spec cobre o que era necessário para levar o `com.gameChallenge.DeepDive` de "compila"
até "pronto para enviar para review", sem alterar nenhum comportamento de jogo.

## Objetivo

Deixar o projeto arquivável e a listagem completa, com todo o conteúdo que a Apple exige
escrito e verificado, restando apenas as etapas que dependem das credenciais do Richard.

## Levantamento inicial

Estado encontrado, com o que foi verificado e não apenas presumido:

| Item | Estado |
|---|---|
| `xcodebuild archive` Release | Passa, 0 erros, 0 warnings — **exige `Xcode-beta`** (formato de projeto 110) |
| Ícone | Icon Composer (`DeepDive.icon`) corretamente ligado via `ASSETCATALOG_COMPILER_APPICON_NAME` |
| SDKs de terceiros | Nenhum |
| Chamadas de rede | Nenhuma (`URLSession`, `CloudKit` ausentes do código) |
| APIs de "required reason" | Nenhuma — `UserDefaults` e `FileManager` não são usados diretamente |
| Degradação sem Apple Intelligence | Funciona: `Narrator` cai para `facts`, que são prosa pt-BR autoral válida |
| Certificado de distribuição | **Ausente** — só existem identidades `Apple Development` na máquina |

## Decisões

1. **Sem `PrivacyInfo.xcprivacy`.** Sem SDK de terceiros e sem required-reason API, o
   manifesto seria um arquivo cerimonial vazio. Se algum dia entrar uma dependência, ele
   passa a ser obrigatório.
2. **`CFBundleDevelopmentRegion` passa a `pt-BR`.** O jogo é integralmente em português e o
   bundle deve se descrever com honestidade.
3. **`ITSAppUsesNonExemptEncryption = NO` no Info.plist**, em vez de responder o formulário de
   export compliance a cada upload. É verdade: o app não implementa criptografia própria.
4. **Classificação alvo 16+**, com "temas de horror/medo" respondido como *frequente/intenso*.
   Subdeclarar para alcançar mais público troca uma rejeição técnica rápida por uma rejeição
   de conteúdo lenta.
5. **Páginas hospedadas no próprio repositório** via GitHub Pages, em `docs/`, com `.nojekyll`.
   Zero custo e zero infraestrutura nova.
6. **Screenshots pelo Simulator.** O `CLAUDE.md` proíbe o Simulator para *teste* — a regra
   existe porque só o device roda Apple Intelligence. Gerar asset de loja é outro fim, e o
   iPhone 16 do Richard (6.1") não produz o tamanho 6.9" que a Apple exige.

## Critérios de Aceite

- [x] `xcodebuild archive` em Release conclui sem erro nem warning
- [x] `CFBundleDevelopmentRegion` = `pt-BR` no Info.plist compilado
- [x] `ITSAppUsesNonExemptEncryption` = `false` no Info.plist compilado
- [x] `UILaunchStoryboardName` vazia removida
- [x] Política de privacidade e página de suporte escritas e publicáveis
- [x] Nome, subtítulo, keywords, texto promocional e descrição dentro dos limites, verificados por contagem
- [x] Gabarito da classificação etária e das respostas de App Privacy escritos
- [x] Notas para o App Review escritas, incluindo caminho rápido até um final
- [ ] Screenshots 6.9" (1320×2868) capturadas
- [ ] Certificado Apple Distribution criado
- [ ] Build enviado e submetido

## Casos de Borda

- **Aparelho sem Apple Intelligence:** verificado — o jogo permanece completo, com todos os
  caminhos e finais. Documentado nas notas de review para o revisor não confundir a
  narração autoral com bug.
- **Nome já registrado:** `DeepDive: !Save Her` pode colidir. Se a Apple recusar, só o campo
  de nome muda; a descrição não depende dele.
- **Guardrails do Foundation Models:** cenas de morte, loucura e fuga são scripts fixos
  entregues literalmente, justamente para o modelo nunca poder recusar um final.

## Notas Técnicas

Build e archive exigem `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
O `Xcode.app` estável não abre o formato 110 e falha com "future Xcode project file format".

Nenhum arquivo Swift foi tocado. Todas as mudanças estão em `project.pbxproj`.

## Dependências

Nenhuma. Não altera comportamento de jogo.

## Histórico de Revisões

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-30 | Claude Code | Criação e implementação |
