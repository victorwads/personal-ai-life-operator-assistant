# Backlog (WhatsApp Assistant)

Arquivo em: [Docs/Backlog.md](./Backlog.md)

Instrução: antes de qualquer commit relacionado a itens deste backlog, validar que o build está funcionando usando [scripts/check_build_and_restart.sh](../scripts/check_build_and_restart.sh).

Legenda de valor:
- `V5 - Altíssimo`: bug crítico ou valor muito alto para o cliente
- `V4 - Alto`: importante para a experiência ou para a arquitetura
- `V3 - Médio`: relevante, mas não bloqueia o uso principal
- `V2 - Baixo`: melhoria útil, porém não essencial
- `V1 - Muito baixo`: ideia futura ou ajuste opcional

Legenda de risco de desenvolvimento:
- `R1 - Baixíssimo`: implementação direta e pouco sensível
- `R2 - Baixo`: mudança local com pouco impacto colateral
- `R3 - Médio`: exige coordenação entre partes do sistema
- `R4 - Alto`: mexe em fluxo importante ou integrações sensíveis
- `R5 - Muito alto`: pode afetar comportamento central ou exigir migração cuidadosa

Legenda de risco da feature:
- `R1 - Baixíssimo`: feature isolada e com baixo impacto se falhar
- `R2 - Baixo`: efeito colateral limitado e fácil de perceber
- `R3 - Médio`: pode afetar operação real ou exigir fallback claro
- `R4 - Alto`: pode alterar comportamento sensível, mensagens ou automação
- `R5 - Muito alto`: pode expor dados, quebrar fluxo central ou exigir controles fortes

Score de Execução:
- Fórmula base: `valor / ((risco de desenvolvimento * 1.5) + risco da feature)`
- Fator de desbloqueio: `1 + (quantidade de itens que dependem dele / 10)`
- Score final: `score base * fator de desbloqueio`
- Quanto maior o score, melhor candidato para executar agora.
- Bugs críticos de perda de dados/mensagens podem furar a fila mesmo com score menor.

Este arquivo reúne ideias e melhorias para retomarmos depois. Cada item fica separado por uma linha `---`.

Exemplo de prompts para manutenção:
- Execute as alterações do item `## X) Xxxxx Xxx Xxxxx Xxxxx` do arquivo [Docs/Backlog.md](./Backlog.md).
- Pode remover do backlog e comitar as alterações e o backlog inteiro. (após permissão explicita para remover do backlog)

---

## 1) Encontrar chat que não aparece na lista inicial

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.44`

**Descrição**  
Quando a conversa não estiver visível na lista principal do app, o agente deve conseguir pesquisar o nome ou número na barra de busca do WhatsApp Web/Desktop, validar o resultado e abrir o chat certo antes de seguir com a ação.

**Dependências**  
- `Nenhuma`

**Por que isso entra no backlog**  
É um fluxo mais complexo e frágil, porque depende de busca, seleção de resultado, validação de ambiguidade e sincronização do contexto do chat antes do envio.

---

## 2) Arquivar conversa

Valor: `V3 - Médio`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.40`

**Descrição**  
Adicionar a capacidade de arquivar uma conversa específica para manter o conjunto de chats ativos mais enxuto e organizado. O comportamento padrão do WhatsApp de reabrir o chat quando chegam mensagens novas continua valendo.

**Dependências**  
- `Nenhuma`

**Evidências/seletores observados na row**  
- `data-testid="list-item-0"` identifica a linha da conversa.
- `data-testid="cell-frame-container"`, `data-testid="cell-frame-title"` e `data-testid="cell-frame-primary-detail"` organizam a estrutura visual da row.
- `data-testid="last-msg-status"` expõe o preview/status da última mensagem.
- `data-testid="status-dblcheck"` indica o estado de entrega/leitura do último envio.
- `aria-label="Conversa fixada"` mostra que há ao menos um estado de pin visível nessa row.
- Neste trecho específico ainda não apareceu o menu ou botão de arquivar; isso precisa ser encontrado em outro nível da UI ou em outro estado do DOM.

**Comportamento desejado**  
- Primeiro executar `SelecionarConversa` com validação por título para garantir que o chat certo está realmente ativo.
- Só depois disparar o atalho de arquivar conversa.
- Se a validação por título falhar, o arquivamento não deve acontecer.
- O fluxo deve evitar arquivar a conversa errada mesmo quando houver resultados parecidos na lista.

**Notas técnicas**  
- Como o WhatsApp Web já expõe o atalho de arquivar conversa, o fluxo mais seguro é usar o seletor do chat como etapa de confirmação e depois acionar o atalho de teclado.
- O código deve tratar `SelecionarConversa` como pré-condição obrigatória antes do evento de arquivar.
- Essa ordem também reduz o risco de arquivar um item incorreto quando a lista estiver parcialmente carregada ou ambígua.

**Por que isso entra no backlog**  
É uma melhoria útil para controle de contexto e limpeza da lista de conversas, com uma implementação relativamente direta em comparação com o fluxo de busca/resolução de chat.

---

## 3) Delete de chat com preservação opcional de configurações

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Revisar o fluxo de delete de chats para separar claramente duas intenções: apagar só as mensagens do chat ou apagar também as configurações operacionais do chat. Hoje a tela trata `delete chat` e `delete all` como exclusão completa, mas na prática o usuário precisa poder escolher se quer manter ou descartar permissões, preferências de extração de mídia e outros campos que fazem o chat continuar “conhecido” pelo sistema. Esse item já existia conceitualmente na versão anterior e precisa ser reconstruído na V2 com confirmação explícita em camadas.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Ao clicar em delete de um chat, mostrar uma confirmação com duas opções: apagar só mensagens ou apagar mensagens + configurações.
- Ao clicar em delete all, mostrar a mesma distinção em nível global.
- Permitir que a operação “apagar só mensagens” remova o conteúdo e o hash/estado derivado, mas preserve campos operacionais do chat.
- Permitir que a operação “apagar mensagens + configurações” limpe o chat por completo, incluindo permissões, preferências e outros metadados operacionais.
- Evitar que `Allow`/`Deny` e outras preferências sejam perdidas por acidente quando o usuário só queria limpar a conversa.

**Notas técnicas**  
- O fluxo precisa usar uma caixa de confirmação com duas camadas de decisão, para não confundir limpeza de conteúdo com limpeza de cadastro do chat.
- A implementação deve separar claramente o que é `chat cleanup` do que é `chat metadata cleanup`.
- O modelo/repositório de chat deve continuar consistente depois da exclusão parcial, sem deixar estado quebrado ou meio apagado.
- O estado de `stateHash` e outros campos derivados pode ser resetado quando o conteúdo for removido, mas os campos operacionais devem sobreviver quando o usuário escolher manter as configurações.

**Por que isso entra no backlog**  
Isso devolve controle fino ao usuário e evita perder regras importantes do chat quando a intenção era só limpar mensagens, não apagar o cadastro operacional inteiro.

---

## 4) Ações de `handled` por mensagem e em lote no chat

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Adicionar ações operacionais por mensagem dentro da conversa para marcar `handled` e `unhandled` de forma explícita. Hoje a UI já exibe um badge de `Handled`/`Unhandled`, então ele pode virar o ponto de interação principal: clicar no badge alterna o estado daquela mensagem. Além disso, a conversa precisa oferecer um atalho no header para marcar todo o chat como handled, e também uma ação em lote para marcar mensagens mais antigas ou mais novas a partir de uma mensagem escolhida.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Permitir alternar o estado de uma mensagem ao clicar no badge de `Handled`/`Unhandled`.
- Adicionar no header da conversa uma ação do tipo `Mark all handled`.
- Permitir marcar uma mensagem específica e todas as anteriores como handled.
- Permitir marcar uma mensagem específica e todas as posteriores como unhandled.
- Oferecer seleção em lote com checkbox visível nas linhas para aplicar ações em massa.

**Notas técnicas**  
- A regra de `handled` continua sendo por mensagem, não por chat inteiro, então o lote deve apenas facilitar a edição de várias mensagens de uma vez.
- O fluxo de “marcar como handled” precisa respeitar a ordem temporal da conversa, para não criar buracos no meio da sequência.
- A ação em lote pode usar um popover, menu contextual ou menu de linha, desde que a direção da alteração fique clara para o usuário.
- O badge existente em `ChatMessageBubbleView` já é a melhor ancoragem visual para essa ação e pode ser usado como disparador da interação.
- O cabeçalho da conversa pode expor a ação global sem esconder o controle individual por mensagem.

**Por que isso entra no backlog**  
Isso transforma a tela de chat em uma ferramenta operacional de verdade, permitindo corrigir estados de leitura e processamento sem depender só de ações automáticas do runtime.

---

## 8) Indicador de "digitando" durante o processamento

Valor: `V3 - Médio`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.35`

**Descrição**  
Adicionar uma melhoria de UX para mostrar que o assistente está processando uma conversa depois de receber e ler as mensagens recentes. A ideia é ativar um estado visual de `digitando` no chat enquanto o sistema pensa e prepara a resposta, para que a pessoa que está esperando veja que o assistente está ativo.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Quando `list_recent_messages` for chamado para um chat específico, o chat pode entrar em estado de `digitando`.
- Enquanto a resposta estiver sendo processada, o indicador pode variar de forma sutil, como se o WhatsApp Web estivesse alternando caracteres na área de escrita.
- O estado deve ser usado como feedback visual temporário durante o processamento.
- Quando o envio da resposta terminar, o estado de `digitando` deve ser removido.

**Por que isso entra no backlog**  
Isso não muda a lógica principal do assistente, mas melhora bastante a percepção de responsividade para quem está aguardando a resposta.

---

## 10) Testes automatizados de integração com MCP server

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.77`

**Descrição**  
Criar uma suíte de testes automatizados em Swift para validar o fluxo real da aplicação contra o MCP server reiniciado. A ideia é cobrir testes de integração que chamem as tools do servidor e validem os comportamentos principais da integração com WhatsApp Web.

**Dependências**  
- `Nenhuma`

**Estratégia desejada**  
- Usar um grupo fixo de testes no WhatsApp, com nome como `testes integrados`, para executar as validações.
- Esse chat deve servir como ambiente controlado para envio de mensagem, listagem de mensagens e outras tools críticas.
- Os testes de integração devem agir como um client do MCP server, chamando as tools depois que o servidor for reiniciado.
- Como o WhatsApp Web não permite múltiplas instâncias independentes, os testes devem rodar contra a mesma instância ativa após o build e reinício do servidor.
- Cada fluxo de integração existente ou nova criado no projeto deve ter cobertura de teste automatizado correspondente. ex.: listagem de chats, leitura de mensagens, envio de mensagens, arquivamento, pesquisa de chat, etc.

**Notas técnicas**  
- O melhor encaixe é evoluir [scripts/check_build_and_restart.sh](../scripts/check_build_and_restart.sh), porque ele já centraliza gerar o projeto, buildar e reiniciar o app; esse fluxo pode passar a opcionalmente executar a suíte de integração logo após o restart.
- Se os testes não ficarem acoplados ao script, o [README.md](../README.md) precisa explicar com clareza como rodá-los e em que momento eles entram no processo de manutenção.
- O prompt de implementação deve deixar explícito que, ao concluir essa feature, o [README.md](../README.md) precisa ser atualizado para refletir o novo fluxo.
- Antes de codar, confirmar os nomes reais de targets, alvos de teste e arquivos envolvidos, porque essa estrutura pode ter mudado desde o planejamento.

**Regra de desenvolvimento desejada**  
- Não permitir commit de manutenção relevante sem executar os testes automatizados aplicáveis e validar que passaram.
- Os prompts e instruções de manutenção devem exigir a execução dos testes antes do commit.
- A regra operacional ideal é: build, restart e execução dos testes no mesmo fluxo sempre que possível.

**Por que isso entra no backlog**  
Isso reduz regressões, formaliza o uso do servidor como alvo de testes e dá mais confiança para evoluir a integração sem quebrar o fluxo real do WhatsApp.

---

## 13) Contrato de humanização pós-tool

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.44`

**Descrição**  
Alterar o contrato de `speak_to_client`, `send_message` e `ask_to_client` para que o runtime em Swift receba contexto adicional de forma explícita antes de humanizar a saída. O agente principal continua decidindo normalmente, mas passa mais dados na requisição MCP, como motivo, contexto, memórias relevantes e preferências de comunicação. Depois disso, o runtime encaminha a mensagem para um modelo separado de humanização, sem reasoning, que apenas reescreve o texto final.

Hoje a comunicação já existe, mas ainda mistura decisão operacional com linguagem final. Essa camada nova serve para separar melhor as responsabilidades e permitir que o sistema seja mais humano sem exigir que o agente principal carregue toda a estratégia de estilo no mesmo prompt.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Essa feature depende da existência da tela/runtime de controle do LM Studio.
- O agente principal não deve precisar saber que existe uma etapa posterior de humanização.
- O runtime deve separar o fluxo operacional do fluxo social, tratando a humanização como uma etapa stateless.
- O modelo de humanização deve receber apenas o contexto necessário para ajustar tom e naturalidade.
- O `system prompt` principal do projeto vai precisar ser ajustado para refletir esse novo fluxo em duas camadas.
- `speak_to_client`, `send_message` e `ask_to_client` vão precisar de mais campos obrigatórios para alimentar a etapa de humanização com contexto suficiente.

**Por que isso entra no backlog**  
Isso diminui o acoplamento entre decisão operacional e linguagem social, deixando o sistema mais modular e permitindo que o assistente fale de forma mais natural sem misturar decisão com estilo.

---

## 17) i18n no app e idiomas iniciais

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Adicionar suporte de internacionalização no app, começando pelos nomes dos menus do macOS e já prevendo um pacote inicial de idiomas para a interface principal. A primeira etapa pode ser tornar os itens como `File`, `Edit`, `View`, `Window`, `Help` e os menus internos do app dependentes de strings traduzíveis, e o primeiro conjunto suportado deve incluir `Portuguese`, `English`, `Spanish`, `Mandarin Chinese`, `Hindi` e `French`.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Centralizar textos de interface em uma camada de tradução.
- Começar pelos nomes dos menus do app e do macOS.
- Permitir que a app escolha idioma de forma consistente sem hardcode espalhado.
- Suportar inicialmente `Portuguese`, `English`, `Spanish`, `Mandarin Chinese`, `Hindi` e `French`.
- Manter o comportamento atual como padrão enquanto o restante da interface ainda não for traduzido.

**Notas técnicas**  
- Esse item pode começar com um conjunto pequeno de chaves de tradução para validar a estrutura.
- A arquitetura precisa facilitar expansão futura para outras telas sem refatoração grande.
- Vale confirmar se a estratégia vai seguir idioma do sistema, configuração manual ou ambos.

**Por que isso entra no backlog**  
Isso prepara o app para uma interface mais acessível e organizada, e permite começar pela parte mais visível e estruturante: os menus e o pacote inicial de idiomas.

---

## 23) Respostas rápidas sugeridas no `ask_to_client` e no app mobile

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Permitir que o `ask_to_client` retorne, além da pergunta principal, um array `suggested_fast_responses` com 2 a 5 respostas curtas, objetivas e prontas para toque. A ideia é que o usuário possa responder sem digitar, tanto dentro do app mobile quanto diretamente por notificação, facilitando respostas rápidas quando o contexto for simples.

**Dependências**  
- `41) Firebase observável com cache local sempre atualizado`

**Comportamento desejado**  
- O `ask_to_client` pode preencher `suggested_fast_responses` com opções curtas e úteis.
- O app mobile deve exibir essas respostas rápidas como botões de ação.
- A notificação do app mobile deve permitir responder rapidamente, sem precisar abrir a app em alguns casos.
- O usuário ainda deve poder digitar uma resposta manual, se preferir.
- As respostas rápidas precisam ser curtas, objetivas e derivadas do contexto da pergunta.

**Notas técnicas**  
- O contrato de `ask_to_client` precisa aceitar esse novo campo de saída sem quebrar o fluxo atual.
- O app mobile precisa ler essas opções e mapear a seleção para o mesmo canal de resposta do chat original.
- A feature deve funcionar bem tanto em telas abertas quanto em ações rápidas por notificação.
- Vale definir um limite máximo de opções para não poluir a UI nem a notificação.
- O conteúdo sugerido deve ser contextual, mas não deve depender de inferência complexa demais para continuar útil no uso rápido.

**Por que isso entra no backlog**  
Isso acelera muito o ciclo de resposta do usuário, reduz atrito para mensagens simples e deixa o app mobile mais útil como camada de interação imediata.

---

## 24) MVP do app mobile: Home voice-first

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.67`

**Descrição**  
Definir e implementar o primeiro recorte real do app Android como uma Home centrada em voz. O MVP deve priorizar `ask_to_client` e `speak_to_client`, com STT/TTS nativos, lista de solicitações de voz pendentes e histórico recente de itens resolvidos. O app base já existe em `Apps/Android` e já mostra partes de memórias e voz, mas ainda está cru o suficiente para que esse item continue sendo o fechamento do MVP real.

**Dependências**  
- `41) Firebase observável com cache local sempre atualizado`

**Regras desejadas**  
- A Home deve ser a tela principal e responder imediatamente se existe algo pendente para o usuário.
- A navegação do MVP deve ser mínima e não incluir áreas administrativas que só poluem a experiência.
- O fluxo de `ask_to_client` precisa guardar a pendência e o momento de resolução de forma imutável, incluindo a data em que o item foi marcado como handled.
- O `speak_to_client` deve ser apresentado como feedback de voz direto, sem exigir que o usuário navegue em submenus.
- O app deve manter suporte a STT e TTS como parte central da experiência.
- A lista de itens concluídos deve existir para futuro acompanhamento, mas sem competir visualmente com a pendência principal da Home.

**Por que isso entra no backlog**  
Esse item cristaliza o verdadeiro foco do app mobile no primeiro lançamento: ser a interface de voz do assistente remoto, simples o bastante para familiares usarem sem atrito e clara o suficiente para o desenvolvimento seguir um caminho único.

---

## 27) Auto-scroll do reasoning no LM Studio

Valor: `V3 - Médio`
Risco de Desenvolvimento: `R2 - Baixo`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.75`

**Descrição**  
Fazer a tela do LM Studio acompanhar automaticamente o `reasoning` e o crescimento da resposta, mantendo o scroll sempre no final enquanto o conteúdo se estende. A ideia é que, durante a geração, a área de visualização role para baixo sozinha para mostrar o trecho mais recente sem exigir intervenção manual do usuário.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Manter a timeline/visualização presa ao final enquanto novas linhas de `reasoning` ou eventos chegam.
- Evitar que o usuário perca a parte mais recente da resposta durante a geração.
- Permitir que o scroll automático pare ou seja manualmente ajustado se o usuário começar a inspecionar o histórico.
- Retomar o auto-scroll quando uma nova geração começar.

**Notas técnicas**  
- O comportamento deve considerar tanto `reasoning` quanto outros eventos em streaming que aumentem a altura da área.
- O auto-scroll precisa ser suave o suficiente para não atrapalhar a leitura, mas firme o bastante para manter o final visível.
- Se o usuário interagir manualmente com a timeline, vale preservar essa intenção até a próxima sessão/stream.

**Por que isso entra no backlog**  
Isso melhora a leitura do raciocínio em tempo real e evita que a informação mais recente fique escondida fora da tela enquanto o LM Studio está gerando conteúdo.

---

## 29) `Unresolve` de subjects com motivo obrigatório

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Adicionar a ação de `Unresolve` para subjects na UI e no app mobile, permitindo reabrir um assunto que foi resolvido cedo demais ou que ainda não terminou de verdade. Ao usar essa ação, o usuário deve preencher um motivo obrigatório de reabertura, que pode se chamar `bronca`, para deixar explícito por que o subject não deve ser encerrado agora.

**Dependências**  
- `41) Firebase observável com cache local sempre atualizado`

**Comportamento desejado**  
- Permitir desfazer o estado de `resolve` de um subject.
- Exigir um motivo obrigatório ao reabrir o subject.
- Manter o subject aberto até que ele seja realmente concluído.
- Exibir a ação tanto na UI local quanto no app mobile.
- Registrar o motivo da reabertura no histórico operacional do subject.

**Notas técnicas**  
- A ação precisa atualizar o estado do subject sem apagar o histórico do que já aconteceu.
- O campo `bronca` pode ser apenas o rótulo de interface, mas o motivo precisa ser persistido de forma auditável.
- O runtime não deve considerar o subject resolvido novamente até uma nova resolução explícita.
- Vale deixar claro na modelagem que `unresolve` é uma reversão operacional, não um cancelamento.

**Por que isso entra no backlog**  
Isso evita que assuntos sejam fechados cedo demais e dá ao usuário uma forma clara de reabrir um fluxo com contexto e justificativa explícitos.

---

## 30) Gmail, Calendar e alarmes de subject com wake events

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R5 - Muito alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.48`

**Descrição**  
Integrar oficialmente o MCP server de Gmail e Calendar ao prompt operacional do assistente, deixando claro como ele deve lidar com e-mails, eventos e compromissos de calendário. Além disso, criar uma camada de alarmes ligada a `subjects`, para que o assistente possa gerar eventos de despertar, receber avisos antes da hora marcada e continuar lembrando o usuário até o item ser resolvido, adiado (`snooze`) ou encerrado de verdade.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Incluir Gmail e Calendar como partes explícitas do prompt do sistema.
- Persistir em memória preferências recorrentes sobre como tratar e-mail e calendário.
- Permitir que o assistente sempre lembre de regras como “me avise por áudio quando um evento chegar”.
- Criar alarmes vinculados a subjects.
- Tratar alarmes como eventos que acordam o assistente quando chegam ao horário ou a um tempo antes do compromisso.
- Permitir `resolve`, `snooze` ou manutenção aberta do alarme até ele ser realmente tratado.
- Avisar com antecedência quando houver compromisso próximo, por exemplo com `speak_to_client(...)` ou alerta equivalente.

**Notas técnicas**  
- O prompt operacional precisa documentar a rotina de Gmail e Calendar, não só as tools isoladas.
- O comportamento sobre e-mail e calendário deve ser aprendido e persistido como memória quando for uma preferência durável do usuário.
- O sistema precisa ter uma forma de despertar por tempo ou por alarme, mesmo que isso envolva um scheduler local, timer persistido ou integração com `wait_for_event`.
- O alarme precisa funcionar como um subject próprio, para que tenha rastreamento, abertura, acompanhamento e fechamento.
- Vale definir se o aviso antecipado será sempre por voz, por notificação ou por ambos, dependendo do contexto.

**Por que isso entra no backlog**  
Isso transforma o assistente em uma secretária de verdade, capaz de acompanhar compromissos e e-mails com antecedência, gerar cutucadas automáticas e manter tarefas temporais vivas até que o usuário realmente as resolva.

---

## 33) Tooling para colocar chat na deny list de forma permanente

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Criar uma tooling para o assistente marcar um chat como ignorado para sempre, sem depender de edição manual da deny list pelo nome. Essa ação deve ser usada apenas quando o cliente deixar explícito que nunca mais quer ouvir falar daquele chat, como grupos irrelevantes, conversas de baixa prioridade ou contatos que não devem mais entrar no acompanhamento contínuo.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Permitir que o assistente coloque um chat em block/deny list de forma permanente.
- Exigir que a intenção de permanência fique explícita, para evitar bloqueios acidentais.
- Deixar explícito na descrição da tool que, para o assistente, essa ação é irreversível.
- Garantir que o chat nunca mais volte a aparecer para o assistente depois do `ignore forever`.
- Fazer com que mensagens futuras daquele chat também sejam ignoradas pelo runtime, mesmo que cheguem normalmente.
- Evitar incluir esse chat em buscas, waits, notificações e acompanhamentos futuros.
- Manter o registro da exclusão com contexto suficiente para auditoria e reversão, se necessário.
- Deixar claro que a ação é equivalente a “ignore forever”, não a um mute temporário.

**Notas técnicas**  
- A tooling deve aceitar o identificador correto do chat, não apenas o nome digitado manualmente.
- Vale manter a regra separada de muting/silencing temporário, porque aqui o efeito é permanente.
- A descrição da tool precisa tratar a ação como irreversível do ponto de vista operacional do assistente, para reduzir risco de uso indevido.
- O runtime pode precisar atualizar índices, caches e qualquer fila de eventos pendentes para que o chat realmente suma do fluxo operacional.
- Se houver histórico ou subjects abertos ligados a esse chat, é importante definir se eles são apenas despriorizados ou formalmente encerrados.

**Por que isso entra no backlog**  
Isso reduz ruído operacional e dá ao assistente uma forma segura e explícita de nunca mais acompanhar chats que o cliente não quer ver de novo.

---

## 35) Menu Gmail/Calendar com assistente de configuração

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.68`

**Descrição**  
Criar um menu/área dedicada para Gmail e Calendar dentro da aplicação, com um assistente de configuração que explique autenticação, permissões, credenciais e como ativar cada integração. Esse menu deve servir tanto para testar as tools quanto para orientar o setup inicial, incluindo onde ficam as credenciais, como vincular as contas e como validar que o MCP está pronto. A visão é algo como um “Google” dentro do app, com Gmail e Calendar organizados e um fluxo claro de setup.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Exibir Gmail e Calendar em um menu próprio, separado do restante do Server.
- Permitir testar as tools dessas integrações a partir da UI.
- Incluir um assistente de configuração que explique o fluxo de autenticação.
- Orientar o usuário sobre credenciais, permissões e ativação por perfil.
- Manter o menu oculto ou inativo quando as integrações estiverem desabilitadas.

**Notas técnicas**  
- Esse fluxo deve conversar com a base que já existe em `LMStudioScreen.swift` e com a configuração persistida em `SettingsScreen.swift`.
- O assistente de configuração pode gerar instruções operacionais como criar pasta, baixar credencial, referenciar arquivo e apontar o caminho certo.
- Vale separar claramente o que é “ver status/testar tool” do que é “configurar conta”, para não misturar setup com uso diário.
- A UI precisa deixar transparente que a ativação é por perfil, não um toggle global escondido.

**Por que isso entra no backlog**  
Isso reduz fricção para configurar Gmail e Calendar e prepara o terreno para o sistema de múltiplas contas sem exigir que o usuário decore detalhes técnicos.

---

## 36) Arquitetura multi-conta para Gmail e Calendar por perfil

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R5 - Muito alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.48`

**Descrição**  
Criar a arquitetura de múltiplas contas para Gmail e Calendar, separando provider, conta e runtime de MCP de forma explícita. Hoje a aplicação ainda se comporta como se houvesse um único fluxo de Google por contexto, então a meta aqui é permitir várias contas por profile, com isolamento de credenciais, configuração e estado. Isso precisa valer tanto para perfis locais quanto para a evolução futura com sincronização global, para que um profile possa ter contas pessoais, de trabalho e de clientes sem compartilhar token ou contexto por acidente.

**Dependências**  
- `Menu Gmail/Calendar com assistente de configuração`

**Comportamento desejado**  
- Separar claramente `provider` e `account`.
- Permitir múltiplas contas por profile para Gmail e Calendar.
- Isolar credenciais, tokens e diretórios de configuração por conta.
- Evitar que uma conta de um profile seja reutilizada automaticamente por outro.
- Permitir que o app liste, ative, desative e teste cada conta de forma independente.
- Preparar a UI e o runtime para um futuro app mobile ou acesso remoto sem misturar dados entre contas.

**Notas técnicas**  
- Hoje o ponto de partida é o `mcp/gmail` injetado em `LMStudioSessionManager.swift`, então essa lógica precisa deixar de ser “uma conta implícita” e virar “uma coleção de contas”.
- O modelo de perfil já existe em `AppProfile.swift` e o armazenamento por perfil já passa por `FirestoreCollections.swift` e `FirestoreSettingsService(profileID:)`; essa nova camada deve se apoiar nisso em vez de criar um atalho global.
- A implementação deve prever múltiplos conjuntos de credenciais e, se necessário, múltiplas instâncias MCP por conta.
- O assistente de configuração do item anterior vira a porta de entrada dessa arquitetura, mas a persistência e o isolamento real ficam aqui.

**Por que isso entra no backlog**  
Isso é o que transforma Gmail e Calendar de um setup único e manual em uma plataforma realmente multi-conta, segura e escalável para vários perfis e futuros clientes remotos.

---

## 37) Memórias categorizadas e `list_memories` filtrável

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Estruturar as memórias em categorias explícitas e fazer o `list_memories` funcionar em dois modos: listar tudo sem argumento e listar apenas um subconjunto quando a categoria for informada. A ideia é que memórias de comportamento e contexto deixem de ficar todas misturadas num bloco único, para que o runtime consiga buscar só o que importa para um cenário específico, como e-mail, calendário, subjects, personalidade ou preferências do cliente.

**Dependências**  
- `Gmail, Calendar e alarmes de subject com wake events`
- `Arquitetura multi-conta para Gmail e Calendar por perfil`

**Comportamento desejado**  
- Manter `list_memories()` sem argumento para listar tudo.
- Permitir `list_memories(category)` ou equivalente para filtrar por categoria.
- Organizar memórias em grupos como `email`, `calendar`, `subjects`, `personality`, `client_preferences`, `people`, `whatsapp`, `voice` e `assistant_behavior`.
- Facilitar o carregamento de memórias relevantes sem precisar varrer todo o banco.
- Permitir que Gmail e Calendar usem preferências específicas sem misturar com memórias genéricas.

**Notas técnicas**  
- O contrato da memória precisa carregar um campo de categoria persistido, não só um título solto.
- Algumas memórias continuam globais e sem categoria forte, mas várias instruções duráveis passam a viver em buckets claros.
- O prompt pode continuar pedindo `list_memories()` na inicialização, mas o runtime ganha a capacidade de buscar por categoria quando o contexto pedir.
- Se o sistema migrar para Firebase, essa categorização precisa continuar sendo preservada na coleção correspondente.
- Vale manter compatibilidade com memórias antigas sem categoria, tratando-as como um bucket `general` ou equivalente.

**Por que isso entra no backlog**  
Isso torna o contexto durável muito mais útil e evita que o assistente misture preferências de e-mail, calendário, personalidade e subjects no mesmo saco sem necessidade.

---

## 39) Desativar extração de imagem e sticker por chat

Valor: `V3 - Médio`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.40`

**Descrição**  
Permitir que alguns chats tenham uma regra explícita para não tentar extrair imagem e sticker na lista de mensagens. Hoje o parser já consegue identificar `image`, `sticker` e outros tipos de mídia, mas nem todo chat precisa desse esforço de leitura. Em alguns casos, o ideal é marcar o chat como “não extrair mídia” e seguir só com o conteúdo textual/operacional.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Permitir marcar um chat com uma política de “não ler mídia”.
- Quando essa regra estiver ativa, o runtime deve ignorar tentativa de extração de imagem/sticker daquele chat.
- O chat continua normal para texto, pendências, waits e demais operações.
- A regra deve ser explícita por chat, não um bloqueio global da integração.
- O uso dessa regra deve ser fácil de entender na UI, como um toggle ou bloco de configuração do próprio chat.

**Notas técnicas**  
- O modelo já sabe classificar `MessageKind` como `image`, `voice`, `document`, `deleted` e `unknown`, então a feature aqui é controlar quando vale a pena tentar extrair essas mídias.
- Vale guardar essa preferência no mesmo lugar onde ficam outras propriedades operacionais do chat, para não virar uma condição solta espalhada pelo parser.
- A regra deve ser diferente de deny-list: o chat continua ativo, só muda o nível de leitura de mídia.
- O parser e a UI precisam respeitar essa política para não gastar esforço tentando interpretar mídia que o usuário não quer acompanhar.

**Por que isso entra no backlog**  
Isso reduz ruído e processamento desnecessário em chats onde mídia não é útil, sem perder a conversa nem os eventos textuais importantes.

---

## 40) Revisar ordenação real da lista de chats com inferência contextual

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.63`

**Descrição**  
Revisar a forma como a lista de chats é ordenada para que a data/hora da última mensagem seja a fonte real de verdade, mesmo quando o WhatsApp Web não expõe um timestamp completo no HTML. O comportamento atual ainda pode se confundir quando mensagens antigas são crawladas depois de mensagens novas, porque a ordem de inserção e a ordem temporal real nem sempre coincidem. A nova regra precisa usar o timestamp exato quando existir e, quando ele não estiver disponível, inferir a data da mensagem usando os registros vizinhos do mesmo chat, a ordem real do crawling e os campos de hora já disponíveis.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Priorizar o timestamp exato quando ele vier completo no HTML/metadado.
- Quando só existir a hora, inferir a data usando mensagens anteriores e posteriores do mesmo chat.
- Quando mensagens vizinhas concordarem na mesma data, usar essa data como base para a mensagem sem data completa.
- Preservar a hora exata da mensagem quando ela existir, mesmo que a data precise ser inferida.
- Evitar que mensagens crawladas depois apareçam na frente só por terem sido descobertas mais tarde.
- Manter a ordenação visual e a ordenação interna do repositório alinhadas com a data derivada final.

**Notas técnicas**  
- A entidade de chat já guarda `listOrder`, mas a ordenação final não deve depender só da ordem em que os itens foram encontrados.
- O algoritmo pode combinar `createDateAt`, a posição no crawl, o `messageId` e os timestamps dos itens vizinhos para derivar a melhor data possível.
- Se a inferência ficar ambígua demais, o fallback deve preservar uma ordem estável e previsível, sem saltos bruscos entre sessões.
- O resultado final precisa ser armazenado em formato ordenável, idealmente `ISO string`, para que sorting lexicográfico continue confiável.
- Esse item substitui a antiga estratégia simplificada de metadados, porque agora a regra precisa ser mais robusta para mensagens de mídia, mensagens antigas e recrawls tardios.

**Por que isso entra no backlog**  
Sem essa inferência contextual, a lista continua vulnerável a reordenação errada quando o crawl encontra mensagens fora da sequência temporal ideal. Este item fecha essa lacuna com uma regra mais resistente ao comportamento real do WhatsApp Web.

---

## 41) Firebase observável com cache local sempre atualizado

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.53`

**Descrição**  
Garantir que os repositórios baseados em Firebase funcionem como observáveis de verdade, mantendo o cache local sempre sincronizado com o estado remoto. A ideia é que a aplicação não dependa apenas de leituras pontuais do Firebase, mas de listeners/observers sobre as collections para refletir imediatamente novas mensagens, alterações e deleções no cache local e na UI.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Abrir listeners/observadores para as collections relevantes quando o profile ou o serviço iniciar.
- Manter o cache local atualizado automaticamente com inserções, alterações e deleções.
- Garantir que o estado observado sobreviva à navegação entre telas e perfis enquanto o service estiver ativo.
- Usar o snapshot local como fonte de leitura rápida para a UI e para o runtime.
- Evitar que o app precise “recarregar do zero” para perceber mudanças feitas por outro dispositivo ou por outra parte do sistema.

**Notas técnicas**  
- O Firebase já fornece sincronização local por snapshot listeners, então a implementação deve aproveitar isso em vez de reinventar polling.
- A inicialização precisa registrar os observers no boot do profile, especialmente para settings, memórias, subjects e pendências operacionais.
- O cache local precisa reagir bem a deleções, porque esse é o tipo de mudança que mais costuma deixar estado obsoleto se o listener não estiver bem amarrado.
- Esse item é a peça que fecha a experiência multi-dispositivo depois da base de mobile/Firebase já estar disponível.

**Por que isso entra no backlog**  
Sem observação contínua das collections, o Firebase vira só uma camada de storage remoto e não uma fonte de verdade sincronizada em tempo real. Este item garante que a experiência fique realmente viva e consistente entre dispositivos.

---

## 42) `wait_for_event` com fontes de evento ampliadas

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.53`

**Descrição**  
Recriar o `wait_for_event` como uma ferramenta de orquestração realmente multi-fonte, capaz de aguardar e sinalizar diferentes tipos de eventos do runtime sem ficar restrito a chat pendente. O novo contrato precisa escutar eventos de mensagens de chat, respostas de `client voice`, eventos do sistema, pendências de assuntos, e também mudanças ligadas a `suspended` issues, inclusive quando o prazo de suspensão expirar e algo precisar acordar o assistente de novo.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Escutar eventos de mensagens recebidas e pendências de chat.
- Escutar eventos de `client voice`, incluindo respostas e novos pedidos do fluxo de voz.
- Escutar eventos de sistema e eventos operacionais gerais.
- Disparar wake events quando uma issue suspensa atingir o fim do prazo de suspensão.
- Diferenciar o tipo de evento retornado para que o agente saiba se precisa ler mensagens, revisar voz, retomar issue ou apenas reiniciar o ciclo.
- Manter o evento read only: aguardar e informar, mas não consumir pendências sozinho.

**Notas técnicas**  
- O resultado do wait precisa carregar um tipo de evento explícito, não só um rótulo genérico.
- A implementação deve considerar `PendingWorkProvider`s, filas de eventos e timers/schedulers de suspensão como fontes legítimas.
- O fluxo novo precisa conviver com o reinício de sessão e com os demais ciclos do runtime, sem perder o contexto do tipo de evento retornado.
- `wait_for_event` deixa de ser só “tem chat não lido?” e passa a ser a borda de espera do runtime operacional.

**Por que isso entra no backlog**  
O comportamento antigo ficou estreito demais para o que o runtime precisa hoje. Esta nova versão fecha a lacuna de eventos do assistente e permite que ele acorde por mensagem, voz, sistema ou expiração de suspensão sem misturar tudo num único tipo genérico.

---

## 43) Gerenciamento de janelas do profile com frame inicial saudável

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Recriar o gerenciamento de janelas do profile para que a experiência volte a ser confortável na V2. Na prática, o profile window não pode abrir espremido, com sidebar e conteúdo cortados, obrigando o usuário a maximizar só para conseguir ler. Esse era um comportamento que já existia de forma melhor na versão anterior e precisa ser reconstruído agora, com abertura em um frame inicial saudável, mínimo visual mais generoso e um estado de janela que faça sentido no macOS.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Abrir a janela do profile com tamanho inicial confortável para leitura e uso.
- Evitar que a sidebar ou o painel principal fiquem cortados na primeira abertura.
- Respeitar um mínimo de largura/altura para não quebrar o layout.
- Recuperar ou preservar o estado da janela quando o profile for reaberto, se isso fizer parte da melhor experiência.
- Manter o comportamento consistente entre profiles diferentes.

**Notas técnicas**  
- O frame inicial precisa ser definido de forma mais cuidadosa do que o tamanho padrão atual da janela.
- Se houver persistência de tamanho/posição por profile, ela deve ser aplicada antes da primeira renderização visível.
- A solução deve continuar compatível com o `AppWindowManager` e com o `ProfileWindowHostView`, sem introduzir um fluxo especial por tela.
- Vale revisar também se a janela precisa começar maximizada, em tamanho grande padrão ou com restauração do último frame salvo.

**Por que isso entra no backlog**  
Uma janela de profile difícil de ler quebra a usabilidade logo no começo da sessão. Esse item recupera uma experiência que a V1 já entregava melhor e que a V2 precisa voltar a oferecer.

---

## 44) Padronização visual das listas e master-detail no app

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Criar um padrão visual único para as telas que apresentam listas de itens e painéis de detalhe no app. Hoje a tela de `Issues` já usa um `Picker` segmentado para filtrar `active`, `suspended`, `resolved`, `cancelled` e `all`, mas a área de listagem ainda depende de cards soltos em `ScrollView`/`LazyVStack`, com uso irregular do espaço e sem uma estrutura de lista consistente entre features. O objetivo é criar um componente/padrão compartilhado para as listas desktop, para que `Issues`, `Memories`, `Sensitive Data`, `Client Voice` e `Sent Messages` tenham uma base visual mais uniforme. A tela de `Chats` já está mais próxima do padrão ideal por usar `NavigationSplitView`, e o `Tools Browser` também deveria seguir essa mesma proposta de master-detail, em vez de ficar com uma organização visual diferente.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Padronizar a estrutura visual das telas com lista + detalhe.
- Reaproveitar o mesmo padrão de navegação master-detail quando a feature tiver esse formato.
- Melhorar o aproveitamento do espaço horizontal no desktop.
- Manter cada feature responsável pelo conteúdo da linha, mas não pela estrutura base da lista.
- Usar o mesmo idioma visual para filtros, lista e detalhe em telas parecidas.

**Notas técnicas**  
- O componente do filtro em `Issues` já é um `Picker` com estilo `.segmented`, então o novo trabalho é mais sobre a estrutura de lista do que sobre filtros.
- `DSListCardRow` já existe e pode ser parte da solução, mas ele não resolve sozinho a organização inteira da tela.
- O padrão deve nascer no Shared UI ou em um componente reutilizável equivalente, para não duplicar o mesmo arranjo em várias features.
- `Chats` e `Tools Browser` servem como referência para master-detail; a meta é aproximar as demais telas desse comportamento sem forçar tudo a virar igual.
- O item deve considerar que algumas telas precisam de lista lateral, outras de cards empilhados e outras de detail pane, mas todas precisam parecer parte da mesma aplicação.

**Por que isso entra no backlog**  
Essa padronização melhora muito a leitura do app inteiro, reduz inconsistência entre features e dá uma base visual mais sólida para qualquer nova tela que venha depois.

---

## 45) Ações manuais de status na tela de Issues

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Permitir que o usuário altere manualmente o status de uma issue diretamente na UI, porque hoje a tela funciona mais como visualização do que como ação operacional. O usuário precisa conseguir mudar uma issue de `active` para `resolved`, `cancelled` ou `suspended`, além de desfazer um estado errado quando a IA ou a automação concluírem algo cedo demais. A regra de `suspended` continua especial: ela precisa de uma data de suspensão, então não pode ser tratada como uma troca simples de status sem campos adicionais.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Adicionar uma ação por issue para trocar o status manualmente.
- Exigir motivo quando a mudança representar resolução, cancelamento ou reversão operacional.
- Exigir data/horário quando o novo status for `suspended`.
- Permitir corrigir manualmente um status que a IA tenha definido errado.
- Manter o histórico da alteração visível para auditoria.

**Notas técnicas**  
- A UI pode usar um seletor, menu contextual ou popover de ação por linha, mas a mudança precisa ser explícita e confirmada antes de salvar.
- `suspended` deve continuar carregando `suspendUntil` e, se fizer sentido, um motivo associado.
- Essas ações devem atualizar o mesmo modelo de issue e continuar registrando timeline items para não perder o histórico.
- O design atual de `Issues` é list-only, então essa feature acrescenta a camada de ação que falta sem remover o padrão de listagem.

**Por que isso entra no backlog**  
Isso devolve ao usuário controle operacional real sobre `Issues`, permitindo corrigir estados, abrir exceções e registrar decisões humanas quando a automação não acertar de primeira.

---

## 47) Bootstrapping de memories fora do prompt de tool calling

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Remover a dependência do `list_memories` do prompt operacional e passar a injetar todas as memórias duráveis no começo de cada sessão de IA, como parte fixa do primeiro bloco de contexto do usuário. A ideia é que o `AIConnection` já monte a sessão com as memórias antes de qualquer reasoning ou tool calling, deixando o prompt do sistema mais simples e reduzindo a necessidade de o modelo gastar chamadas só para recuperar contexto permanente. A tool de listagem pode continuar existindo para uso manual e de debug, mas deixa de ser a fonte principal de carregamento do contexto durável na sessão normal.

**Dependências**  
- `37) Memórias categorizadas e `list_memories` filtrável`
- `41) Firebase observável com cache local sempre atualizado`

**Comportamento desejado**  
- Injetar as memórias no boot da sessão como texto fixo inicial do usuário, antes do prompt operacional.
- Tirar do prompt a obrigação de chamar `list_memories()` para conhecer o contexto permanente.
- Manter o prompt do sistema mais curto e menos dependente de tool calling para contexto durável.
- Atualizar a carga inicial de memórias sempre que houver mudança relevante no cache.
- Preservar uma forma de listagem manual de memories para manutenção e debug, sem depender dela no fluxo padrão.

**Notas técnicas**  
- O `AIConnectionConversationContextBuilder` já monta system prompt + user prompt, então esse é o ponto natural para append do bloco de memórias.
- O bootstrap deve receber memórias em formato estável para favorecer cache de input do provedor de IA.
- Quando houver mudança nas memórias, a sessão nova pode perder cache inicial, mas esse custo é aceitável porque a memória não muda com tanta frequência.
- O `list_memories` continua útil como ferramenta de inspeção, mas a carga automática deve virar responsabilidade da conexão de IA, não do prompt.

**Por que isso entra no backlog**  
Isso simplifica o contrato mental do assistente, melhora a chance de reaproveitamento de cache da API de IA e garante que o contexto durável esteja sempre presente sem depender de uma tool call adicional.

---

## 48) Componentes reutilizáveis de voz e request do cliente

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.50`

**Descrição**  
Reaproveitar a base de `Client Voice` como uma camada mais modular, com componentes de voz que possam ser usados por outras features sem precisar passar dependência manualmente em cada view. A parte de reconhecimento e fala já existe de forma separada no backend de speech, mas falta elevar isso para componentes de UI e helpers de janela que “se virem sozinhos” com as configurações globais de voz, iniciando, cancelando, retomando e exibindo input de fala de forma padronizada.

**Dependências**  
- `42) `wait_for_event` com fontes de evento ampliadas`

**Comportamento desejado**  
- Extrair um componente de input de voz reutilizável para outras features.
- Permitir que o componente controle microfone, gravação, cancelamento e retomada sem exigir wiring manual por tela.
- Fazer o componente usar as configurações globais de voz já disponíveis na aplicação.
- Criar uma helper/window reutilizável para abrir a captura de áudio/resposta sem duplicar lógica em cada feature.

**Notas técnicas**  
- O objetivo não é empurrar o estado de voz para cada tela, e sim trazer esse comportamento para um componente reutilizável que se adapte às configurações globais.
- A janela/helper de captura deve ser reaproveitável por outras features que precisem de fala rápida do cliente.

**Por que isso entra no backlog**  
Isso transforma `Client Voice` numa base mais arquitetural e reutilizável para a experiência de voz, além de abrir um canal real para o cliente iniciar trabalho diretamente com o assistente.

---

## 49) Request manual do cliente como evento operacional

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.53`

**Descrição**  
Adicionar na `Client Voice` um botão/ação para o cliente criar uma request nova diretamente, sem depender de WhatsApp, de uma pergunta já aberta ou de uma tool disparada pelo assistente. Essa request deve entrar no runtime como evento explícito e virar o ponto de partida para a IA criar e tratar a issue correspondente. Hoje o cliente ainda não tem como pedir algo diretamente ao assistente por esse canal, então essa feature fecha a ponta de entrada humana no fluxo de voz.

**Dependências**  
- `42) `wait_for_event` com fontes de evento ampliadas`

**Comportamento desejado**  
- Permitir que o cliente crie uma request manual diretamente na `Client Voice`.
- Fazer essa request entrar no fluxo operacional como evento do runtime.
- Garantir que a IA trate essa entrada como um pedido iniciado pelo cliente, não como uma resposta automática a outro evento.
- Persistir o registro da request no mesmo modelo de interação já usado pela feature.
- Permitir que esse evento seja consumido pelo `wait_for_event` ampliado e pelo prompt operacional.

**Notas técnicas**  
- A nova request deve usar o mesmo backbone de `ClientInteractionRequest`, mas com origem explícita de cliente.
- O prompt operacional precisa entender que o runtime pode despertar por uma request manual do cliente, além de WhatsApp e voice replies.
- Esse evento deve ser fácil de diferenciar de mensagens, respostas e speak requests já existentes.
- A entrada manual do cliente precisa criar o contexto necessário para que o assistente abra o trabalho certo na sequência.

**Por que isso entra no backlog**  
Isso dá ao cliente um canal direto para iniciar trabalho com o assistente, fechando a lacuna entre ouvir, responder e pedir algo novo sem depender de um intermediário.

---

## 50) Integração real de e-mail

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R5 - Muito alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.48`

**Descrição**  
Implementar a integração real de e-mail da aplicação, indo além da tela/área visual que hoje ainda funciona mais como espaço de configuração ou placeholder. A feature precisa existir de ponta a ponta para que o assistente consiga realmente ler, reagir e operar e-mails como parte do runtime, sem depender só de texto no prompt ou de uma representação visual da área de e-mail. Hoje o app já reserva esse espaço na navegação, então esse item é o trabalho de transformar esse espaço em integração funcional de verdade.

**Dependências**  
- `35) Menu Gmail/Calendar com assistente de configuração`
- `36) Arquitetura multi-conta para Gmail e Calendar por perfil`

**Comportamento desejado**  
- Integrar o fluxo de e-mail ao runtime operacional do assistente.
- Permitir leitura e reação a e-mails como eventos reais do sistema.
- Conectar a área de e-mail com o contexto e as preferências do assistente.
- Evitar que a tela de e-mail seja apenas decorativa ou de status.
- Preparar a feature para uso por múltiplas contas quando a arquitetura de contas estiver ativa.

**Notas técnicas**  
- O item precisa aproveitar a base de configuração e multi-conta já pensada para Gmail.
- A tela/área de e-mail pode continuar servindo como workspace visual, mas agora deve refletir integração de verdade.
- O comportamento operacional precisa nascer do provider/conta já autenticada, não de dados estáticos.
- O prompt e o runtime devem conseguir se referir a e-mails como uma fonte real de eventos e trabalho.

**Por que isso entra no backlog**  
Sem essa integração, o espaço de e-mail no app fica só como placeholder. Este item fecha a lacuna e transforma e-mail em parte real do assistente.

---

## 51) Integração real de calendário

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R5 - Muito alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.48`

**Descrição**  
Implementar a integração real de calendário da aplicação, transformando a área/tela de calendário em uma funcionalidade operacional e não apenas visual. A meta é que o assistente consiga usar calendário como fonte de eventos, compromissos e wakeups reais, com o fluxo funcionando de ponta a ponta dentro do runtime. Hoje a interface de calendário já existe como espaço reservado; esse item é a construção da integração de verdade em cima desse espaço.

**Dependências**  
- `35) Menu Gmail/Calendar com assistente de configuração`
- `36) Arquitetura multi-conta para Gmail e Calendar por perfil`

**Comportamento desejado**  
- Integrar o calendário ao runtime operacional do assistente.
- Permitir leitura de eventos, compromissos e lembretes como eventos reais.
- Usar o calendário como gatilho para wake events e follow-up.
- Manter a área visual do calendário como workspace útil e não só como placeholder.
- Preparar a feature para múltiplas contas quando a arquitetura estiver pronta.

**Notas técnicas**  
- O item deve reutilizar a infraestrutura de setup e multi-conta já prevista para Calendar.
- A tela/área de calendário pode continuar como parte do Command Center, mas agora precisa refletir integração funcional.
- O comportamento operacional deve vir da conta autenticada e configurada no runtime.
- O prompt e os fluxos de evento precisam conseguir tratar calendário como fonte real de ações e alertas.

**Por que isso entra no backlog**  
Sem essa integração, o calendário continua sendo só uma promessa visual. Este item transforma o espaço reservado em funcionalidade efetiva do assistente.

---

## 52) Modo desenvolvedor nas settings do Command Center

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.57`

**Descrição**  
Adicionar uma configuração própria do Command Center para ativar ou desativar o modo desenvolvedor. Quando esse modo estiver desligado, algumas áreas de debug e diagnóstico devem desaparecer da navegação, como `Web YAML Debug`, `Native YAML Debug`, `Logs` e outras superfícies de inspeção mais técnicas. Quando estiver ligado, esses itens voltam a aparecer. A ideia é deixar o Command Center mais limpo no uso normal, sem perder a capacidade de expor as ferramentas internas quando o desenvolvedor precisar.

**Dependências**  
- `44) Padronização visual das listas e master-detail no app`

**Comportamento desejado**  
- Exibir uma configuração de `developer mode` nas settings do Command Center.
- Esconder itens de debug e logs quando o modo estiver desligado.
- Reexibir essas áreas quando o modo estiver ligado.
- Manter o estado persistido por profile, se fizer sentido para a experiência do app.
- Deixar claro na UI quais partes são de uso normal e quais são de depuração.

**Notas técnicas**  
- O `CommandCenterMenuRegistry` já tem campos para visibilidade por developer mode, então o item deve plugar nisso em vez de criar uma regra paralela.
- A lógica de visibilidade pode continuar centralizada no registry, mas o estado precisa vir de settings reais e não de flag hardcoded.
- `Web YAML Debug`, `Native YAML Debug` e `Logs` são os primeiros alvos óbvios de filtragem, junto com qualquer outra área debug que venha depois.
- O ideal é que a configuração viva no mesmo fluxo de settings do profile para que a visibilidade seja consistente na abertura da janela.

**Por que isso entra no backlog**  
Isso limpa a experiência do app para uso diário sem perder o acesso às ferramentas de diagnóstico quando for necessário depurar a integração ou o runtime.

---

## 53) Avaliar `AIJSONValue` como bridge JSON compartilhada

Valor: `V3 - Médio`
Risco de Desenvolvimento: `R2 - Baixo`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.52`

**Descrição**  
Avaliar se o `AIJSONValue` deve sair de `AIConnection` e virar uma bridge JSON compartilhada para outras features que precisem interpretar, normalizar ou serializar payloads JSON de forma flexível. Hoje esse tipo já é muito bom para o streaming: ele aceita objetos, arrays, valores primitivos e tenta decodificar JSON mesmo quando o modelo mistura texto antes do payload, encontra o primeiro objeto válido e ainda lida com casos de JSON duplamente codificado. Isso o torna um candidato forte para virar padrão arquitetural em vez de permanecer como duplicação isolada.

**Dependências**  
- `48) Componentes reutilizáveis de voz e request do cliente`

**Comportamento desejado**  
- Revisar se outras features poderiam reaproveitar essa ponte JSON.
- Decidir se o tipo deve permanecer isolado em `AIConnection` ou migrar para `Shared`.
- Verificar se o comportamento de parsing tolerante deve virar um padrão comum da codebase.
- Documentar a decisão nas architectures relevantes, se a unificação fizer sentido.
- Evitar criar novas cópias do mesmo conceito em outras features.

**Notas técnicas**  
- O arquivo atual já tem os pontos essenciais: `parseObject(from:)`, `init(any:)`, `foundationValue` e `jsonString(prettyPrinted:)`.
- Ele também já cobre casos úteis como texto antes do JSON, markdown fences e JSON duplamente codificado, o que o torna mais geral do que um parser estreito de streaming.
- Se a unificação acontecer, vale revisar as boundaries em `AIConnection/Architecture.md` e `Shared/Architecture.md` para não misturar responsabilidades sem necessidade.
- Mesmo que a decisão final seja mantê-lo local, esse item serve para documentar a análise arquitetural e evitar duplicação futura.

**Por que isso entra no backlog**  
Isso não é urgente, mas pode virar uma base bem valiosa para o resto da aplicação se outras features começarem a precisar de um bridge JSON mais tolerante e reutilizável.

---

## 54) Normalizar comparação do `SentMessages` para mensagens longas

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.55`

**Descrição**  
Investigar e corrigir o fluxo de confirmação de envio em `SentMessages` quando a mensagem enviada é longa, tem emojis ou volta do WhatsApp com formatação ligeiramente diferente da string original. Hoje o sistema pode interpretar como falha uma mensagem que já foi enviada corretamente, o que faz o agente tentar reenviar sem necessidade. O objetivo é tornar a comparação mais tolerante a diferenças cosméticas como quebras de linha, espaços extras, trimming e pequenas variações de renderização entre o texto composto e o texto crawled do WhatsApp.

**Dependências**  
- `28) Histórico de mensagens com falha e retry do send`
- `32) Registro permanente de mensagens enviadas`

**Comportamento desejado**  
- Padronizar a comparação entre a mensagem enviada e a mensagem observada no WhatsApp antes de decidir se o send falhou.
- Ignorar diferenças irrelevantes de whitespace, quebra de linha e trimming quando isso não alterar o conteúdo semântico.
- Cobrir casos com emojis, mensagens longas e textos que voltam com pequenas diferenças de formatação.
- Evitar resend duplicado quando a confirmação falha apenas por mismatch textual superficial.
- Validar o comportamento com testes manuais e depois consolidar em testes unitários.

**Notas técnicas**  
- O melhor caminho é centralizar uma camada de normalização/canonicalização antes da comparação de confirmação, em vez de espalhar `trim` e regras soltas pelo fluxo.
- A normalização deve ser conservadora o suficiente para não mascarar mensagens realmente diferentes, especialmente em fluxos de atendimento real.
- Vale revisar o ponto exato onde o `SentMessage` passa de `pending` para `sent`/`failed`, porque é ali que a comparação precisa ficar resiliente.
- Este item deve ser acompanhado por testes com exemplos reais de mensagens longas e variações de quebra de linha/emoji para evitar regressão.

**Por que isso entra no backlog**  
Esse bug afeta diretamente a confiança no envio: uma confirmação falsa pode causar mensagens repetidas ao cliente, o que é ruim tanto para a experiência quanto para a operação do assistente.

---

## 55) Extrair imagem em alta resolução na mensagem

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Investigar e corrigir o fluxo de extração de imagens das mensagens do WhatsApp para evitar que o sistema pegue apenas a miniatura ou uma versão de baixa resolução da mídia. O objetivo é garantir que a extração capture a imagem na maior qualidade disponível na mensagem, ou que o fluxo consiga trazer mais de uma variante da mídia quando isso fizer sentido.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Preferir sempre a mídia em alta resolução quando ela existir na mensagem.
- Evitar salvar só a imagem reduzida/previsualização quando houver uma versão melhor disponível.
- Se o WhatsApp expuser mais de uma variante útil da mídia, permitir capturar mais de uma imagem por mensagem.
- Validar o resultado com exemplos reais de mensagens com imagem para não regressar para thumbnail borrada.

**Notas técnicas**  
- O ponto principal é descobrir qual campo do HTML/DOM ou metadado leva à mídia original e não só à preview image.
- Se houver múltiplas URLs ou caminhos para a mesma imagem, o parser deve escolher a melhor variante disponível antes de persistir.
- Vale revisar também se a camada de armazenamento precisa aceitar múltiplos assets por mensagem de forma consistente.
- Esse item deve ser testado com mensagens reais, porque a diferença entre thumbnail e original pode variar conforme o tipo de mídia e o estado da conversa.

**Por que isso entra no backlog**  
Imagem borrada ou em baixa resolução prejudica tanto a leitura humana quanto qualquer fluxo futuro que dependa de mídia correta, então vale corrigir isso na base.

---

## 56) Incluir imagens no contexto de IA durante o tool calling

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.48`

**Descrição**  
Adicionar suporte real para que mensagens com imagem entrem no contexto do modelo de IA durante o fluxo de tool calling. Hoje os modelos usados já aceitam visão, mas o runtime ainda não deixa claro como a imagem deve ser enviada para a IA quando a mensagem do WhatsApp vem com mídia. O objetivo deste item é descobrir e implementar a forma correta de incluir a imagem no contexto da request, seja enviando o asset diretamente para o modelo, seja convertendo a mídia em uma representação textual/estruturada que o modelo consiga consumir sem perder a informação visual.

**Dependências**  
- `55) Extrair imagem em alta resolução na mensagem`

**Comportamento desejado**  
- Incluir imagens relevantes no contexto quando a mensagem do WhatsApp vier com mídia visual.
- Definir se o fluxo vai usar imagem bruta, asset multimodal ou uma descrição textual gerada antes da chamada ao modelo.
- Garantir que o modelo receba a mídia certa junto da mensagem certa, sem confundir o contexto textual com o visual.
- Cobrir o caso de mensagens com imagem antes de ativar qualquer lógica automática de interpretação visual.
- Validar o comportamento com exemplos reais do WhatsApp para evitar perda da informação visual.

**Notas técnicas**  
- O primeiro passo é investigar a capacidade real do pipeline atual de IA para receber multimodalidade no formato que a codebase já usa.
- Se o modelo não puder receber imagem diretamente no ponto atual do tool calling, a alternativa pode ser gerar uma descrição/metadata estruturada e anexar isso à request.
- Esse item precisa esclarecer a fronteira entre `Chats`, `WhatsAppCrawling` e `AIConnection`, para não misturar extração de mídia com transporte da request.
- Como há risco de duplicar payload ou de enviar a imagem errada para o contexto errado, vale implementar com bastante cobertura de teste e exemplos reais.

**Por que isso entra no backlog**  
Isso habilita o assistente a realmente “ver” o que chegou no WhatsApp, o que é uma base importante para responder melhor a mensagens que dependem de mídia e não só de texto.
