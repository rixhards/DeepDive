# Submissão — passo a passo

> As etapas que dependem das suas credenciais. Nenhuma delas pode ser feita por um agente:
> todas envolvem login, certificado ou o botão de publicar.
>
> Conteúdo de listagem para copiar e colar: [`app-store-connect.md`](app-store-connect.md).

---

## Passo 1 — Publicar as páginas (GitHub Pages)

As URLs de privacidade e suporte são **campos obrigatórios** e a Apple verifica se abrem
durante o review.

No GitHub, em `rixhards/DeepDive` → **Settings** → **Pages**:

- **Source:** Deploy from a branch
- **Branch:** `main` · pasta **`/docs`**

Aguarde um ou dois minutos e confirme que as três URLs abrem em aba anônima:

```bash
for u in "" suporte.html privacidade.html; do curl -o /dev/null -s -w "%{http_code}  https://rixhards.github.io/DeepDive/$u\n" "https://rixhards.github.io/DeepDive/$u"; done
```

Todas devem responder `200`.

> **Atenção:** publicar `/docs` torna público **todo** o conteúdo dessa pasta — specs, ADRs e
> notas de decisão inclusive. Se o repositório já for público isso não muda nada. Se for
> privado e você não quiser expor os documentos internos, mova só os três `.html` e o
> `.nojekyll` para um branch `gh-pages` e publique a partir dele.

---

## Passo 2 — Criar o certificado de distribuição

Hoje esta máquina só tem identidades `Apple Development`. Para exportar para a App Store
falta uma `Apple Distribution` — o Xcode cria sozinho, desde que sua função na equipe seja
**Account Holder** ou **Admin**.

1. Abra o projeto no **Xcode-beta** (o Xcode estável não lê o formato deste projeto)
2. **Product** → **Destination** → **Any iOS Device (arm64)**
3. **Product** → **Archive**
4. No Organizer que abrir: **Distribute App** → **App Store Connect** → **Upload**
5. Mantenha **"Automatically manage signing"** — é aqui que o certificado é criado

Para conferir depois que terminar:

```bash
security find-identity -v -p codesigning | grep Distribution
```

---

## Passo 3 — Enviar o build

O upload acontece no fim do passo 2. Depois dele:

- O build aparece em **App Store Connect → TestFlight** como *Processing*
- O processamento leva de alguns minutos a cerca de uma hora
- Você recebe um e-mail se algo for rejeitado no processamento

Como não há mais o formulário de export compliance (resolvido no Info.plist), o build fica
disponível assim que processar.

**Se precisar enviar um segundo build**, incremente o número antes:

```bash
agvtool next-version -all
```

Dois builds nunca podem ter o mesmo `CFBundleVersion` na mesma versão.

---

## Passo 4 — Preencher a versão 1.0

Em **App Store Connect → Apps → DeepDive → Versão 1.0**, com o
[`app-store-connect.md`](app-store-connect.md) aberto ao lado:

- [ ] Nome, subtítulo e categorias (seção 1)
- [ ] Palavras-chave (seção 2)
- [ ] Texto promocional (seção 3)
- [ ] Descrição (seção 4)
- [ ] URLs de suporte, marketing e privacidade (seção 1)
- [ ] Screenshots 6.9"
- [ ] Classificação etária — responda **exatamente** conforme a seção 5
- [ ] App Privacy — "não coletamos dados" (seção 6)
- [ ] Notas para o App Review (seção 7)
- [ ] Selecionar o build processado

---

## Passo 5 — Enviar para review

Antes de clicar, decida como quer o lançamento:

| Opção | Efeito |
|---|---|
| **Liberação manual** | Aprovado ≠ no ar. Você escolhe o momento. **Recomendado para o primeiro app** |
| Liberação automática | Vai ao ar assim que a Apple aprovar, possivelmente de madrugada |
| Liberação em fases | Distribuição gradual em 7 dias. Só faz sentido com base de usuários já existente |

O botão final é **"Add for Review"** → **"Submit to App Review"**.

Expectativa realista: a primeira revisão costuma sair em **24 a 48 horas**. Primeira
submissão de uma conta nova às vezes demora mais.

---

## Se for rejeitado

Não é fracasso, é rotina — a maioria dos apps é rejeitada pelo menos uma vez.

- Responda pelo **Resolution Center**, dentro do próprio App Store Connect
- Peça o ponto específico da guideline se a mensagem vier genérica
- Rejeição de **metadados** (texto, screenshot, classificação) não exige build novo: corrija e
  reenvie na hora
- Rejeição de **binário** exige build novo com número incrementado

Os dois motivos mais prováveis para este app, e a resposta para cada um:

| Motivo | Resposta |
|---|---|
| Classificação etária considerada baixa | Corrigir para o valor que a Apple indicar e reenviar. Por isso o gabarito já vai em 16+ |
| Revisor não entendeu como jogar | As notas de review já trazem o caminho completo até um final em ~2 minutos, em português com tradução |

---

## O que já está pronto

- Info.plist e build settings ajustados e **verificados no binário compilado**
- `archive` em Release passando com 0 erros e 0 warnings
- Política de privacidade, suporte e página inicial escritas
- Toda a copy da listagem, com contagem de caracteres conferida
- Gabarito de classificação etária e de App Privacy
- Notas para o App Review, incluindo caminho rápido até um final
