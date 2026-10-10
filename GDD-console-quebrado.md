# GDD — Console Quebrado (título provisório)

**Engine:** Godot 4.5 · **Linguagem:** GDScript · **Gênero:** plataforma 2D com manipulação de hardware

---

## 1. Visão geral

O jogador joga um plataforma 2D na tela de um console portátil gigante e quebrado. O console fica no centro da tela, em 3D (visual voxel), e o plataforma roda dentro da tela dele. O desafio real é o hardware: só existe **um fio**, então **só um controle funciona por vez**, e a energia vem de pilhas que descarregam.

O jogo **nunca pausa**. Plugar, girar o console e trocar pilha acontecem em tempo real enquanto o plataforma roda.

## 2. Pilares

1. **O hardware é o desafio.** A dificuldade vem de manipular o console, não só de pular plataformas.
2. **Pressa constante.** O jogo nunca para, então cada manipulação tem custo.
3. **Atalho com preço.** Trapacear (curto-circuito) resolve um problema agora e cobra energia.

## 3. O console

- Renderizado em 3D no centro da tela, aparência **voxel**.
- **Frente:** tela onde roda o plataforma 2D.
- **Traseira:** também 2D; mostra os conectores e as duas pilhas.
- O jogador gira o console para alternar entre frente e traseira (o jogo continua rodando durante o giro).

## 4. Controles e o fio

| Controle | Função |
|---|---|
| D-pad | Movimento |
| A | Pulo |
| B | Ação / corrida |
| Start | (função a definir) |

### Regras do fio
- Existe **um único fio**: apenas **um controle ativo por vez**.
- Para trocar: girar o console → plugar o fio em outro conector (na traseira) → girar de volta.
- **Plugar exige segurar/pressionar até o fim.** Um indicador mostra se o plug está `PARCIAL` ou `COMPLETO`.
- Sem controle de movimento ativo, o personagem **fica parado**.

## 5. Curto-circuito

Mecânica intencional, provocada pelo jogador.

- **Gatilho:** plug `PARCIAL` + uso do botão correspondente → curto.
- **Efeito:** o botão passa a funcionar **automaticamente, para sempre** na fase.
- **Custo:** `energy = energy / 2` (metade da energia **atual**).
- Não tem limite de quantidade de curtos; o custo em energia é o limitador natural.
- O botão em curto **não ocupa o fio**: o fio fica livre para outro conector, permitindo vários botões ativos ao mesmo tempo.
- **Irreversível** dentro da fase. Reseta por completo na fase seguinte.

## 6. Energia (pilhas)

A energia é tratada como **um único valor** (`energy`, 0–100%).

- O console tem **2 pilhas visíveis na traseira**, que drenam **em paralelo** (representadas visualmente, mas somando uma energia só).
- Há **1 pilha reserva** na UI do jogador (fora do console). Total: 3 pilhas.
- **Energia = vida do jogador.** `energy <= 0` sem concluir a fase → **game over**.
- Efeito visual de energia baixa: a tela escurece e pisca até apagar.

### Troca de pilha
- **Sem tampa.** O jogador clica na pilha que quer trocar, arrasta para fora, pega a pilha nova da UI e arrasta para dentro.
- Pilha nova: `energy += 50%`, com teto de **100%**.
- A pilha usada **não pode ser reutilizada**.
- Acontece em tempo real, com o jogo rodando.

## 7. Core loop

1. Olhar a fase e identificar qual controle será necessário.
2. Girar o console, plugar o fio (até o fim) e voltar para a frente.
3. Jogar o trecho com o único botão ativo (ou com os botões em curto).
4. Vigiar a energia e trocar pilha quando começar a falhar.
5. Chegar ao fim da fase; a próxima exige trocas mais frequentes ou mais rápidas.

## 8. Progressão (direção, fora do MVP)

- Fases montadas em trechos que pedem um botão cada (andar → pular → correr).
- Mais adiante: pilha drena mais rápido e surgem mais conectores.
- **Cada fase é um novo jogo:** energia, reserva e curtos resetam por completo.

## 9. Escopo do MVP

O primeiro MVP precisa provar apenas:

1. **Controlar o personagem** no plataforma 2D.
2. **Trocar o fio** entre conectores (com giro do console e plug com progresso).
3. **Botões** respondendo somente quando o fio (ou um curto) os ativa.

**Fora do MVP:** fases/level design, progressão, sistema completo de energia e pilhas, polimento visual.

## 10. Notas técnicas (sugestões para Godot 4.5)

> Sugestões de implementação, não decisões fechadas de design.

- O plataforma 2D roda em um `SubViewport`, usado como textura na tela do modelo 3D do console.
- Camada de input própria: o personagem **nunca lê `Input` direto**. Cada botão (`D_PAD`, `A`, `B`, `START`) tem uma fonte de estado: `OFF`, `WIRED` (plug completo) ou `STUCK` (curto).
- Cada conector tem `plug_progress` (0.0 a 1.0); `COMPLETO` ao atingir 1.0. Usar o botão com plug parcial dispara `STUCK`.
- Uma variável `energy` global da fase; curto aplica `energy /= 2`; troca de pilha aplica `energy = min(energy + 50, 100)`.
- Drag and drop das pilhas com estados `INSERIDA`, `ARRASTANDO`, `FORA`.
- Como o jogo nunca pausa, `process_mode` do plataforma permanece sempre ativo.

## 11. Decisões em aberto

- Função do botão **Start** e se ele participa da mecânica de fio/curto.
- Quantidade e posição dos conectores no MVP.
- Taxa de drenagem natural da energia e tempo necessário para plugar por completo.
- Direção do movimento quando o D-pad está em curto (autorun para qual lado?).
- O que acontece com a tela e a energia enquanto uma pilha está fora do slot durante a troca.
- Limiares exatos dos efeitos de energia baixa (quando escurece, quando pisca).
