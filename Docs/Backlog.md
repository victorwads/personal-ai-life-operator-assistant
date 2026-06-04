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

