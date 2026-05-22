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
- `Configuração de seletores via YAML com auto-update`

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
- `Configuração de seletores via YAML com auto-update`

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

## 4) Mapeamento do parsing do WhatsApp Web via YAML com auto-update

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.52`

**Descrição**  
Extrair do código atual todo o mapeamento usado para interpretar o WhatsApp Web e mover esse conhecimento para um arquivo `YAML` versionado. Isso inclui seletores, caminhos relativos, alternativas de match, hooks de JavaScript quando existirem e a estrutura hierárquica de leitura da tela. O `YAML` deve ser bundlado no app como padrão, mas o runtime pode baixar uma versão mais recente via uma URL configurável nas Settings. Se a URL estiver vazia, o app usa apenas o `YAML` embutido e não tenta atualizar.

**Dependências**  
- `Nenhuma`

**Regras desejadas**  
- O `YAML` precisa carregar metadados como data da versão e versão do schema.
- O app só deve tentar atualizar o `YAML` no momento em que o servidor inicia ou o app abre.
- Se a URL de atualização não estiver configurada, não deve haver tentativa de fetch.
- Se a versão do schema do `YAML` remoto for incompatível com a versão esperada pelo app, a atualização deve ser ignorada.
- Enquanto a versão do schema for compatível, o app pode atualizar só o `YAML` sem exigir atualização do binário.
- Se o schema mudar, a atualização precisa ser feita no app nativo.
- Toda a lógica de parsing atual do WhatsApp Web deve deixar de depender de valores hardcoded espalhados no código e passar a consultar essa configuração centralizada.
- O código não deve ter fallback silencioso para outros seletores fora do `YAML`; se o arquivo faltar ou estiver inválido, o fluxo correspondente não deve funcionar.
- O `YAML` deve permitir múltiplas alternativas por ponto de leitura, para cobrir mudanças de DOM/HTML sem quebrar o fluxo.
- O formato precisa representar relações hierárquicas, como lista de chats, row de chat e seletores relativos dentro da row.
- Parte das chaves estruturais pode continuar hardcoded no código, mas o valor de cada chave precisa vir do `YAML`.
- O modelo deve acomodar tanto seletores CSS/DOM quanto buscas baseadas em JavaScript ou outro mecanismo já usado hoje no parsing.

**Por que isso entra no backlog**  
Isso reduz o acoplamento com o HTML atual do WhatsApp Web e facilita manter o app funcionando quando a interface mudar, sem precisar lançar uma nova versão para cada alteração pequena de estrutura, mantendo o comportamento atual do parser, mas com os mapeamentos centralizados e atualizáveis.

---

## 5) Corrigir ordenação e metadados da lista de chats

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.63`

**Descrição**  
Corrigir o bug em que a listagem de chats fica desordenada quando o WhatsApp Web retorna apenas textos como `quinta-feira` ou horários soltos em vez de uma data completa da última mensagem. O objetivo é encontrar, se existir, a origem correta da data/hora real da última mensagem em formato estruturado, mapear esse valor para algo ordenável, preferencialmente `ISO string`, e usar isso tanto na listagem visual quanto no repositório/ordenação interna.

**Dependências**  
- `Configuração de seletores via YAML com auto-update`

**Contexto observado**  
- No exemplo atual, a row expõe `lastMessageAtText`, `lastMessageDirection`, `lastMessagePreview` e `lastMessageStatus`, mas não mostra um timestamp estruturado.
- O texto exibido pode servir para UI, mas não é confiável para ordenação consistente.
- Se o HTML ou metadado interno trouxer um timestamp em `ISO`, esse campo deve ser o candidato principal para armazenar e ordenar.

**Problema observado**  
- Em `list_chats`, o campo da última mensagem às vezes aparece só como texto humano, sem `ISO date`.
- Quando a última mensagem não traz data completa, a ordenação quebra ou fica parcial.
- Alguns metadados da última mensagem ainda precisam ser recuperados corretamente, incluindo o status da última mensagem.
- A versão nativa já parecia tratar melhor esses dados, mas no Web isso ainda não está estável.

**Objetivo**  
- Encontrar a origem correta da data da última mensagem, se ela existir em algum metadado interno do WhatsApp Web.
- Usar essa data estruturada para ordenar os chats no repositório e na listagem visual.
- Garantir que o status da última mensagem também seja preenchido corretamente.

**Por que isso entra no backlog**  
Sem uma data real e estruturada, a lista não consegue ser ordenada por recência com confiança, o que afeta diretamente a experiência e a leitura operacional dos chats. Como `ISO string` ordena bem lexicograficamente, ela também simplifica a lógica de sorting quando esse dado estiver disponível.

---

## 6) Exposição externa para app mobile e controle por API/Firebase

Valor: `V2 - Baixo`
Risco de Desenvolvimento: `R5 - Muito alto`
Risco da Feature: `R5 - Muito alto`
Score de Execução: `0.16`

**Descrição**  
Externalizar parte da experiência do assistente para uma aplicação mobile ou outra interface cliente, com foco em uma experiência voice-first e leve para o usuário final. O mobile deve receber e responder pendências de voz do assistente, mostrar a Home como ponto principal do dia a dia e deixar integrações mais pesadas ou administrativas para fases posteriores.

**Dependências**  
- `Nenhuma`

**Capacidades desejadas**  
- Expor sincronização via Firebase para pendências de voz, estado operacional e histórico recente.
- Manter uma API direta ou túnel apenas para casos que realmente precisem de acesso pontual ao Mac, como dados sensíveis e chamadas específicas.
- Permitir envio e recebimento de áudio, incluindo gravação e reprodução no dispositivo remoto quando fizer sentido.
- Permitir reconhecimento de voz no lado do cliente, com uso dos recursos nativos de Android e iOS para STT/TTS.
- Manter a máquina principal como origem do contexto, mas com uma interface externa simples para operação e resposta do usuário.

**Por que isso entra no backlog**  
Isso amplia o alcance do assistente para fora da máquina local e abre caminho para uma experiência portátil e realmente útil no celular, sem exigir que o usuário lide com detalhes de rede ou com a máquina do Mac.

---

## 7) `wait_for_event` não pode consumir pendências

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.67`

**Descrição**  
Corrigir o bug em que a toll `wait_for_event` está marcando como resolvidas ou “handled” conversas que ainda não tiveram suas mensagens lidas pelo assistente. o evento `wait_for_event` deve ser read only e não alterar nada. O que realmente retorna as não lidas e marca elas como lidas, é o `list_recent_messages` e `wait_for_chat_message`.
Hoje o assistente esta perdendo as mensagens pois ele chama o `wait_for_event` para listar os chats não lidos, mas esse endpoint esta marcando eles como lidos, então quando o `list_recent_messages` é chamado, ele não encontra mais nada para ler e vem vazio.

**Dependências**  
- `Nenhuma`

**Regra desejada**  
- `wait_for_event` apenas informa quais chats têm pendência.
- Somente `list_recent_messages` ou `wait_for_chat_message` pode marcar mensagens como `handled` para um chat específico.
- A limpeza de lido/handled deve ocorrer apenas depois do pull real das mensagens do chat.
- A resposta do `wait_for_event` precisa trazer o nome do evento, como `prompt_from_cliente` ou `unhandled_chat`, e não apenas um tipo genérico como `chat_messages`. pois as vezes o evento não é sobre mensagens, mas sobre outra coisa, como um prompt do cliente ou um evento de sistema.
- O payload do evento deve ser explícito o suficiente para distinguir o que aconteceu sem depender de inferência externa.

**Por que isso entra no backlog**  
Esse bug quebra o fluxo de consumo do assistente e faz perder mensagens antes da leitura real, então a responsabilidade de “consumir” precisa ficar restrita ao endpoint certo.

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

## 9) Estados de presente e ausente

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.44`

**Descrição**  
Adicionar um estado global para a aplicação entre `presente` e `ausente`, para que o assistente saiba como se comportar quando o usuário estiver na frente do computador ou não. Quando estiver `presente`, o assistente pode usar o fluxo de `speak_to_client` normalmente. Quando estiver `ausente`, ele deve evitar interromper o usuário e responder de forma mais assíncrona, registrando as pendências para revisão posterior.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Permitir alternar manualmente entre `presente` e `ausente`.
- Quando estiver `presente`, o assistente pode falar normalmente com o usuário e usar o `speak_to_client`.
- Quando estiver `ausente`, o assistente deve informar que o usuário está ocupado e que o assunto será atualizado depois.
- O `ask_to_client` deve ter `timeout`, para evitar ficar esperando indefinidamente uma resposta.
- Se o usuário não responder dentro do `timeout`, o assistente deve assumir comportamento de ausência e seguir o fluxo apropriado.
- Esse estado pode aproveitar o mesmo repositório de pendências já usado para as conversas a responder.

**Por que isso entra no backlog**  
Isso permite que o assistente adapte o comportamento ao contexto real do usuário, melhorando tanto a experiência ao vivo quanto a operação 24 horas por dia.

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

## 18) Detach da WebView em janela independente

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Permitir que a `WebView` da página de `WebView` seja destacada (`detach` / `pop-out`) e aberta em uma janela independente, sem recriar a instância e sem reiniciar o conteúdo carregado. Quando a janela separada fechar, a `WebView` deve voltar para a tela original exatamente na mesma instância.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Adicionar um botão de `detach` na área da `WebView`.
- Ao destacar a `WebView`, abrir uma janela independente usando a mesma instância existente.
- Enquanto a `WebView` estiver destacada, ocultar o item correspondente do menu/tela principal.
- Ao fechar a janela destacada, recolocar a `WebView` na tela original.
- Quando a `WebView` voltar, o item de menu/ação correspondente deve reaparecer.
- Manter o estado da sessão da `WebView` ativo durante todo o processo.

**Notas técnicas**  
- A solução precisa preservar uma única instância de `WKWebView`, movendo apenas o host visual entre containers.
- A `WebView` não pode ficar em duas janelas ao mesmo tempo, então a troca de superview precisa ser controlada com cuidado.
- Se a tela estiver em SwiftUI, a `WKWebView` precisa ficar fora do ciclo de reconstrução da view.
- Vale prever um controller próprio para abrir/fechar a janela destacada sem reinicializar a página.

**Por que isso entra no backlog**  
Isso melhora a usabilidade quando o usuário quer manter a `WebView` separada da interface principal, sem perder contexto nem pagar o custo de recarregar tudo.

---

## 19) Sessões curtas para tools bloqueantes

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.50`

**Descrição**  
Reformular o fluxo de execução do assistente para que ferramentas bloqueantes não mantenham a sessão do LM Studio viva por tempo indefinido. A ideia é que `speak_to_client`, `ask_to_client`, `wait_for_chat_message` e `wait_for_event` passem a operar com um ciclo de sessão curta: a tool é executada, o runtime guarda o estado necessário, a sessão é finalizada e depois retomada quando houver nova resposta, nova mensagem ou novo evento.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- `speak_to_client` deve ter limite de tempo e não pode prender a sessão esperando indefinidamente.
- `ask_to_client` precisa encerrar a sessão depois de disparar a pergunta, preservando contexto para retomada posterior.
- `wait_for_chat_message` deve manter o contexto mínimo necessário para retomar o mesmo assunto quando a resposta do cliente chegar.
- `wait_for_event` deve ser tratado como um ponto de parada explícito: o assistente finaliza a sessão, o runtime aguarda o próximo evento e então inicia uma nova sessão.
- O runtime deve usar `response_id` e/ou `previous_response_id` para retomar o assunto quando fizer sentido.
- O prompt do agente deve deixar claro que qualquer tool bloqueante precisa terminar a rodada atual de chat assim que tiver o estado salvo.

**Notas técnicas**  
- A API do LM Studio não suporta timeouts enormes e sessões longas com tool calls bloqueantes, então o design precisa evitar esperar “para sempre” dentro da mesma rodada.
- O runtime deve armazenar o contexto mínimo de retomada logo após a tool bloquear ou concluir, para reconstruir a próxima sessão sem perder continuidade.
- Para `ask_to_client`, o ideal é tratar a pergunta como início de uma etapa assíncrona, não como uma espera infinita dentro da mesma resposta.
- Para `wait_for_event`, a sessão deve morrer de forma intencional e controlada, em vez de ficar viva só aguardando algo acontecer.

**Por que isso entra no backlog**  
Isso remove a dependência de longas sessões bloqueadas no LM Studio, reduz risco de timeout e torna o assistente mais robusto para rodar por longos períodos sem degradar a conversa.

---

## 20) Agrupar eventos SSE em blocos de timeline

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.73`

**Descrição**  
Melhorar a visualização dos eventos SSE do LM Studio para que eventos relacionados apareçam agrupados como um único bloco na timeline. Em vez de mostrar `tool_call.start`, `tool_call.arguments` e `tool_call.success` ou `tool_call.failure` como itens separados e poluentes, a UI deve apresentar um único cartão/linha principal da tool, com os detalhes expansíveis de argumentos e resultado.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Agrupar eventos de tool call em um único bloco visual.
- Mostrar `tool_call.start` como início do bloco, com argumentos e resultado dentro dele.
- Manter os detalhes de `tool_call.arguments` e `tool_call.success`/`tool_call.failure` acessíveis por expansão ou drill-down.
- Continuar exibindo eventos simples como `message`, `reasoning` e `error` de forma separada quando fizer sentido.
- Reduzir poluição visual na timeline sem perder a informação bruta do stream.

**Notas técnicas**  
- A camada de UI deve interpretar a sequência de eventos do SSE como uma entidade composta, não apenas como uma lista linear.
- O agrupamento precisa preservar a ordem temporal real dos eventos, mas condensar os que pertencem à mesma tool call.
- Vale manter os payloads completos disponíveis no detalhe expandido para debug.
- O agrupamento deve ser compatível com futuras ferramentas ou eventos que sigam padrão semelhante.

**Por que isso entra no backlog**  
Isso deixa a timeline muito mais legível e próxima da forma como uma pessoa entende o que aconteceu durante a execução, sem sacrificar o acesso aos detalhes técnicos.

---

## 21) Captura automática do User-Agent real do navegador

Valor: `V3 - Médio`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.54`

**Descrição**  
Trocar o `User-Agent` manual atualmente configurado para uma estratégia de captura automática do `User-Agent` real do navegador de referência do usuário. A ideia é expor uma rota HTTP no servidor local do app, por exemplo `/update-user-agent?token=...`, para que o navegador aberto por esse fluxo envie de volta o seu próprio `User-Agent` e o app persista esse valor para uso nas sessões de `WKWebView`.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Detectar o navegador padrão do usuário no macOS.
- Oferecer dois modos de captura:
  - manual, quando o usuário abre a URL da rota no navegador que quiser;
  - automático, quando o `Assistant MCP Server` iniciar e abrir esse endereço em um navegador de referência.
- Validar a chamada com `token` na query string.
- Capturar o `User-Agent` do navegador que abriu a rota e salvar esse valor nas settings.
- Atualizar automaticamente esse valor na inicialização do app ou quando houver indicação confiável de mudança de versão do navegador.
- Manter um fallback manual/persistido caso a coleta automática falhe.
- Alimentar com esse valor a configuração de `customUserAgent` usada nas sessões de `WhatsApp Web`.

**Notas técnicas**  
- Não existe uma API do macOS que leia o `User-Agent` de qualquer navegador de forma genérica sem cooperação do próprio navegador, então a captura precisa acontecer por uma requisição explícita à rota do servidor.
- O servidor precisa aceitar a atualização apenas quando o `token` for válido.
- O valor capturado deve ser armazenado com metadata mínima, como data da captura, browser detectado e método usado.
- A solução precisa prever fallback quando o navegador não estiver disponível, quando a captura for bloqueada ou quando o usuário trocar o navegador padrão.
- O objetivo não é espionar o navegador do usuário em tempo real, e sim manter um `User-Agent` compatível e atualizado para a `WebView`.

**Por que isso entra no backlog**  
Isso reduz a chance de incompatibilidade com o WhatsApp Web quando o navegador do usuário mudar ou atualizar, sem depender de manutenção manual do `User-Agent` nas settings.

---

## 22) Migrar storage e sincronização para Firebase

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R5 - Muito alto`
Risco da Feature: `R5 - Muito alto`
Score de Execução: `0.40`

**Descrição**  
Mudar a base de persistência do projeto para Firebase, centralizando no cloud tudo o que hoje está salvo localmente: mensagens, memórias, configurações, perfis e demais dados operacionais. A mesma base deve atender tanto a aplicação macOS quanto uma futura aplicação Android, com sincronização entre dispositivos e acesso remoto aos perfis sem depender de uma API própria para expor diretamente as informações do usuário.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Guardar mensagens, memórias, configurações e dados de perfis em coleções do Firebase.
- Permitir acesso remoto aos perfis do usuário com autenticação apropriada.
- Eliminar a necessidade de expor uma API própria só para ler/escrever dados do contexto do usuário.
- Permitir que a aplicação macOS e uma futura aplicação Android leiam e escrevam no mesmo backend.
- Definir um modelo de provisionamento/associação de usuário para que perfis remotos possam ser acessados com segurança.
- Manter sincronização entre dispositivos sem depender de storage local como fonte principal de verdade.

**Notas técnicas**  
- A migração precisa definir claramente quais entidades vão para collections, quais ficam em subcollections e como serão indexadas.
- A arquitetura deve prever autenticação, autorização e regras de acesso por usuário/perfil, para que ninguém leia contexto alheio.
- O projeto precisa mapear como o estado local atual será migrado para o Firebase sem perder dados já existentes.
- O cliente macOS e o futuro cliente Android devem passar a tratar o Firebase como backend de verdade, não como espelho parcial.
- Esse item impacta diretamente o desenho de memória, configuração, pendências e qualquer estado persistido do assistente.

**Por que isso entra no backlog**  
Isso transforma o assistente em uma plataforma realmente sincronizada e multi-dispositivo, reduz a dependência de APIs próprias para exposição de dados e abre caminho para acesso remoto consistente aos perfis e ao contexto do usuário.

---

## 23) Respostas rápidas sugeridas no `ask_to_client` e no app mobile

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Permitir que o `ask_to_client` retorne, além da pergunta principal, um array `suggested_fast_responses` com 2 a 5 respostas curtas, objetivas e prontas para toque. A ideia é que o usuário possa responder sem digitar, tanto dentro do app mobile quanto diretamente por notificação, facilitando respostas rápidas quando o contexto for simples.

**Dependências**  
- `Exposição externa para app mobile e controle por API/Firebase`
- `Migrar storage e sincronização para Firebase`

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
Definir e implementar o primeiro recorte real do app Android como uma Home centrada em voz. O MVP deve priorizar `ask_to_client` e `speak_to_client`, com STT/TTS nativos, lista de solicitações de voz pendentes e histórico recente de itens resolvidos. O app não deve expor memórias, issues, nicknames, chats completos, logs ou configurações avançadas nesta fase inicial.

**Dependências**  
- `Exposição externa para app mobile e controle por API/Firebase`
- `Migrar storage e sincronização para Firebase`

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

## 25) System tray icon e saída completa do app

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Adicionar um ícone de `system tray`/`menu bar` para o app, permitindo controlar o ciclo de vida da aplicação fora das janelas principais. A partir desse ícone, o usuário deve conseguir fechar completamente o app quando quiser. Além disso, quando todas as janelas forem fechadas, o comportamento esperado é que o app saia da `Dock`, permaneça em background e continue acessível pelo ícone da barra de menu.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Exibir um ícone na barra de menu do macOS.
- Permitir encerrar o app completamente por esse ícone, sem depender de janelas abertas.
- Quando todas as janelas forem fechadas, o app não deve necessariamente encerrar; ele pode continuar rodando em background.
- O app deve sair da `Dock` quando não houver janelas visíveis.
- O ícone da barra de menu deve continuar oferecendo acesso ao estado e às ações básicas da aplicação.

**Notas técnicas**  
- Esse item envolve ajustar o comportamento padrão de `NSApplication` para coexistir com janela fechada, background e saída explícita.
- A implementação precisa separar “fechar janelas” de “encerrar o processo”.
- O ícone da barra de menu deve ser uma fonte confiável para reabrir ou encerrar o app.
- Vale prever uma decisão clara sobre quando o app deve voltar a aparecer na `Dock` ao reabrir uma janela.

**Por que isso entra no backlog**  
Isso deixa o app mais alinhado com o comportamento esperado de apps macOS residentes, dá controle real de encerramento e evita que o usuário fique preso ao ciclo das janelas.

---

## 26) `response_id` visível e retry contínuo para `plain text`

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.62`

**Descrição**  
Fazer a tela de controle do LM Studio mostrar o `response_id` atual na barra de status do header, dentro da box de `response_id`, e usar esse mesmo `response_id` para reabrir a sessão quando o modelo responder em `plain text` fora do fluxo esperado. A ideia é que a request continue viva de forma controlada: se vier texto puro, o runtime reaproveita o `response_id`, aplica o warning/retry já definido no prompt e chama a chat de novo até conseguir a tool call correta ou até o runtime decidir parar por segurança.

**Dependências**  
- `Sessões curtas para tools bloqueantes`

**Comportamento desejado**  
- Exibir o `response_id` atual na área de status do header.
- Manter o valor sincronizado com a sessão ativa visível na tela.
- Atualizar o display quando a sessão trocar ou quando uma nova resposta for gerada.
- Tornar o `response_id` fácil de copiar/inspecionar durante debug.
- Detectar quando a resposta veio como texto puro fora do fluxo esperado.
- Reusar o `response_id` para continuar a mesma conversa sem perder contexto.
- Reabrir a sessão com o warning/retry já previsto no prompt do sistema.
- Forçar o modelo a emitir a tool call correta na nova tentativa, em vez de aceitar texto puro como resposta operacional.
- Manter a chamada em ciclo de retentativa enquanto fizer sentido para o runtime, sem perder o contexto da conversa.

**Notas técnicas**  
- O header precisa ler o mesmo estado que o runtime usa para retomar sessões.
- A UI não deve depender de logs para mostrar esse identificador.
- Se não houver `response_id` disponível, a tela deve mostrar um estado vazio claro, em vez de inventar valor.
- A correção precisa acontecer no runtime, não só no prompt, porque o erro pode ocorrer mesmo com instrução clara.
- O fluxo de retry deve manter o contexto operacional mínimo e não reiniciar a intenção do usuário do zero.
- O warning usado para o retry deve ser consistente com o que já foi discutido para não criar duas versões diferentes da mesma regra.
- A política de retry precisa evitar loops infinitos se o modelo insistir em responder em texto puro.

**Por que isso entra no backlog**  
Isso facilita a inspeção da sessão corrente do LM Studio, deixa explícito qual identificador deve ser usado para retomar contexto e protege o fluxo operacional contra saídas fora do contrato sem perder continuidade.

---

## 27) Auto-scroll do reasoning no LM Studio

Valor: `V3 - Médio`
Risco de Desenvolvimento: `R2 - Baixo`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.53`

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

## 28) Histórico de mensagens com falha no envio para retry

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Criar um histórico persistente das mensagens que falharam ao serem enviadas, para permitir retentativa posterior sem perder o conteúdo, o destino e o contexto operacional. Quando `send_message` falhar, o runtime deve registrar a tentativa com status de erro, motivo conhecido e dados suficientes para reprocessar depois com segurança.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Registrar mensagens que falharam no envio em um histórico próprio.
- Guardar o chat alvo, o conteúdo da mensagem e o motivo do erro quando disponível.
- Permitir retentativa posterior a partir desse histórico.
- Manter a informação separada de mensagens enviadas com sucesso.
- Evitar perder uma mensagem que falhou por erro transitório de rede, sessão ou validação.

**Notas técnicas**  
- O histórico precisa preservar o payload original da mensagem e o estado da tentativa.
- O retry deve ser capaz de reusar o contexto operacional do `send_message`, sem reconstrução manual pelo usuário.
- Vale registrar timestamps e a última razão de falha para facilitar debug e auditoria.
- Se o sistema migrar mais estados para Firebase, esse histórico pode ser sincronizado junto com os demais dados operacionais.

**Por que isso entra no backlog**  
Isso evita perda silenciosa de mensagens quando o envio falha e permite ao runtime retentar de forma segura sem exigir que o usuário refaça o conteúdo do zero.

---

## 29) `Unresolve` de subjects com motivo obrigatório

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.62`

**Descrição**  
Adicionar a ação de `Unresolve` para subjects na UI e no app mobile, permitindo reabrir um assunto que foi resolvido cedo demais ou que ainda não terminou de verdade. Ao usar essa ação, o usuário deve preencher um motivo obrigatório de reabertura, que pode se chamar `bronca`, para deixar explícito por que o subject não deve ser encerrado agora.

**Dependências**  
- `Exposição externa para app mobile e controle por API/Firebase`

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
