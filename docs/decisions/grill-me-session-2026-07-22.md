# DeepDive — Sessão de Decisões de Design (2026-07-22)

> Este documento registra as decisões tomadas para a fundação da Game Engine (Spec 002).

---

## 1. Estrutura do JSON (Design for the Future)

Decidimos adotar uma abordagem **forward-compatible** para o schema do JSON da narrativa.
Embora a engine inicial (Spec 002) não vá avaliar estados complexos, o JSON já deverá conter a estrutura necessária para suportar:
- **Conditions:** Condições exigidas para que uma opção de resposta apareça para o jogador (ex: `tem_chave_enferrujada == true`).
- **Effects (Flags):** Consequências de escolher uma opção, que alteram o estado do jogo (ex: definir `tem_chave_enferrujada = true`).

**Por quê?** Isso evita que a estrutura fundamental dos arquivos JSON de narrativa e os modelos do Swift precisem ser reescritos ou refatorados massivamente quando a Spec 004+ (Variáveis de Estado) chegar.

## 2. Fronteira da Engine (API do Domínio)

Adotamos a abordagem de **DTO (Data Transfer Object) focado na apresentação** para a comunicação da Engine com a UI.

- A `GameEngine` lerá o arquivo JSON completo (`story.json`) decodificando-o em modelos ricos (ex: `StoryNode`, `StoryOption`, `Condition`, `Effect`).
- Quando a UI (`ChatViewModel`) pedir para avançar a história, a `GameEngine` fará o processamento interno (resolvendo flags e verificando quais opções o jogador tem o direito de ver) e devolverá um modelo simplificado focado em apresentação (ex: `EngineResponse` contendo apenas a string da fala e as opções válidas).

**Por quê?** Isso garante a separação de responsabilidades do MVVM. A UI fica "cega" para as complexidades da narrativa, garantindo que o acoplamento seja mínimo.

## 3. Escopo da Spec 002

A Spec 002 será **estritamente focada na lógica da engine**, isolada da interface.

**O que entra:**
- Classe `GameEngine` baseada numa FSM (Finite State Machine).
- Modelos `Codable` para o schema do JSON (preparados para o futuro).
- Arquivo `story.json` com um mini-cenário expandido da Spec 001.
- Unit Tests robustos provando a navegação pelos nós e a decodificação do JSON.

**O que fica de fora:**
- A UI não vai mudar na Spec 002 (continuará usando dados mockados). A integração real acontecerá apenas na Spec 003.
- Processamento real de sanidade e inventário (a engine apenas lerá esses campos sem aplicá-los por enquanto).

---

*Gerado em 2026-07-22 por Antigravity (Gemini) durante sessão /grill-me com Richard.*
