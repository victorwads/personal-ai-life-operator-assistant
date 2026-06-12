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

## 10) Testes automatizados de integração com MCP server @deprecated

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
Alterar o contrato de `announce_to_client`, `send_message` e `ask_to_client` para que o runtime em Swift receba contexto adicional de forma explícita antes de humanizar a saída. O agente principal continua decidindo normalmente, mas passa mais dados na requisição MCP, como motivo, contexto, memórias relevantes e preferências de comunicação. Depois disso, o runtime encaminha a mensagem para um modelo separado de humanização, sem reasoning, que apenas reescreve o texto final.

Hoje a comunicação já existe, mas ainda mistura decisão operacional com linguagem final. Essa camada nova serve para separar melhor as responsabilidades e permitir que o sistema seja mais humano sem exigir que o agente principal carregue toda a estratégia de estilo no mesmo prompt.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Essa feature depende da existência da tela/runtime de controle do LM Studio.
- O agente principal não deve precisar saber que existe uma etapa posterior de humanização.
- O runtime deve separar o fluxo operacional do fluxo social, tratando a humanização como uma etapa stateless.
- O modelo de humanização deve receber apenas o contexto necessário para ajustar tom e naturalidade.
- O `system prompt` principal do projeto vai precisar ser ajustado para refletir esse novo fluxo em duas camadas.
- `announce_to_client`, `send_message` e `ask_to_client` vão precisar de mais campos obrigatórios para alimentar a etapa de humanização com contexto suficiente.

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
Definir e implementar o primeiro recorte real do app Android como uma Home centrada em voz. O MVP deve priorizar `ask_to_client` e `announce_to_client`, com STT/TTS nativos, lista de solicitações de voz pendentes e histórico recente de itens resolvidos. O app base já existe em `Apps/Android` e já mostra partes de memórias e voz, mas ainda está cru o suficiente para que esse item continue sendo o fechamento do MVP real.

**Dependências**  
- `41) Firebase observável com cache local sempre atualizado`

**Regras desejadas**  
- A Home deve ser a tela principal e responder imediatamente se existe algo pendente para o usuário.
- A navegação do MVP deve ser mínima e não incluir áreas administrativas que só poluem a experiência.
- O fluxo de `ask_to_client` precisa guardar a pendência e o momento de resolução de forma imutável, incluindo a data em que o item foi marcado como handled.
- O `announce_to_client` deve ser apresentado como feedback de voz direto, sem exigir que o usuário navegue em submenus.
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
- Avisar com antecedência quando houver compromisso próximo, por exemplo com `announce_to_client(...)` ou alerta equivalente.

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

## 39) Desativar extração de imagem e sticker por chat - doing @deprecated

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

## 48) Componentes reutilizáveis de voz e request do cliente - doing

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

## 57) Fechar o servidor HTTP do user agent só depois da resposta HTML

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R2 - Baixo`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Corrigir o fluxo da captura automática de `user agent` pela WebView para que o servidor HTTP não seja encerrado antes de devolver a resposta HTML com o `window.close()`. Hoje o navegador já envia o `user agent`, o backend já consegue capturá-lo, mas o servidor é fechado cedo demais e a requisição termina com erro na aba. O comportamento correto é concluir a resposta HTML primeiro e só depois encerrar o servidor HTTP responsável pela captura.

**Dependências**  
- `21) Captura automática de user agent do navegador`

**Comportamento desejado**  
- Capturar o `user agent` assim que a requisição chegar, como já acontece hoje.
- Continuar salvando o `user agent` no momento em que ele é recebido.
- Só encerrar o servidor HTTP depois de responder o HTML final para o navegador.
- Evitar que a aba fique aberta com erro de requisição incompleta.
- Manter o fluxo automático funcionando tanto no modo manual quanto no modo de disparo automático.

**Notas técnicas**  
- O bug está no timing entre capturar o header da request e encerrar o listener/servidor antes do `response body` terminar de ser escrito.
- A correção deve separar claramente “capturar e persistir o `user agent`” de “finalizar o ciclo HTTP com resposta válida”.
- Vale revisar o handler da rota de captura para garantir que o `window.close()` só seja devolvido depois que o body tiver sido enviado com sucesso.
- Essa mudança deve ser pequena, mas precisa ser testada no navegador real para evitar regressão de fechamento prematuro.

**Por que isso entra no backlog**  
Esse bug quebra uma etapa importante da captura automática do `user agent` e deixa a aba em estado de erro, então vale corrigir para o fluxo ficar limpo e confiável.

---

## 58) Suspensão de issues por tempo ou por chat

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.45`

**Descrição**  
Melhorar a feature de `Issues` para que o estado `suspended` possa ser definido por vários gatilhos e motivos, não apenas por um intervalo de tempo. A suspensão pode acontecer, por exemplo, porque existe um `ask_to_client` pendente, porque um chat vinculado ainda não foi respondido, porque o cliente ficou ausente, porque precisa aguardar uma mensagem específica do WhatsApp ou porque um prazo temporal precisa expirar. Em todos os casos, a issue deve sair da suspensão automaticamente quando o gatilho correspondente acontecer, e a timeline precisa registrar claramente por que ela foi suspensa e por que voltou a ficar ativa.

**Dependências**  
- `39) Desativar extração de imagem e sticker por chat` 

**Comportamento desejado**  
- Permitir suspender uma issue por data, por chat, por `ask_to_client` pendente ou por outro gatilho operacional relevante.
- Registrar explicitamente a razão da suspensão, não só o estado final.
- Destravar a issue automaticamente quando a data expirar.
- Destravar a issue automaticamente quando chegar mensagem em qualquer `chatId` vinculado.
- Destravar a issue automaticamente quando um `client request interaction` for respondido ou alterado.
- Destravar a issue automaticamente quando o `ask_to_client` pendente for resolvido.
- Registrar na timeline o motivo da suspensão e também o motivo da saída da suspensão.
- Fazer a tooling de suspensão sempre criar o evento de timeline correspondente no momento em que a issue for suspensa.

**Notas técnicas**  
- O modelo de issue precisa armazenar não só `suspendUntil`, mas também uma lista estruturada de gatilhos de suspensão e desbloqueio.
- Cada gatilho deve poder apontar para `chatId`, `client request interaction`, `ask_to_client` ou um timer, conforme o caso.
- A suspensão por chat precisa conversar com o fluxo de eventos/mensagens já existente, para disparar o desbloqueio quando houver nova atividade relevante.
- A timeline deve registrar o `why suspended` e o `why unsuspended`, para manter rastreabilidade operacional.
- O desbloqueio automático não deve depender de ação manual quando o gatilho temporal ou por mensagem acontecer.
- Vale tratar esse item como uma das regras centrais do runtime, porque ele impacta diretamente como o assistente decide o que pode continuar rodando e o que precisa esperar.

**Por que isso entra no backlog**  
Isso deixa `Issues` mais útil para operação real, porque pausa trabalhos até a hora certa ou até o chat voltar a ter sinal de vida, sem perder rastreabilidade do que aconteceu.

---

## 59) Corrigir compressão do header quando os badges ocupam muito espaço - doing

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R2 - Baixo`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.57`

**Descrição**  
Corrigir o layout do header do `Command Center` para que o título do profile não seja esmagado verticalmente quando a fileira de badges de runtime ocupa muito espaço horizontal. Hoje, quando há vários badges ativos na mesma linha, o texto do título e subtítulo fica comprimido e quebra em colunas estreitas, enquanto os badges continuam com comportamento rígido. A UI precisa ajustar melhor o espaço entre título e status badges, permitindo que o header responda com mais flexibilidade ao tamanho disponível.

**Dependências**  
- `44) Padronização visual das listas e master-detail no app`

**Comportamento desejado**  
- Manter o título do profile legível mesmo com vários badges de runtime.
- Evitar que o texto do header seja reduzido a uma coluna estreita.
- Fazer os badges cederem espaço ou quebrarem de forma mais natural quando o header ficar apertado.
- Preservar a leitura da barra de status sem comprometer o nome do profile.

**Notas técnicas**  
- O ponto principal está em `Server/Sources/Features/CommandCenter/Views/CommandCenterHeaderView.swift`, onde a `HStack` do header concentra o título e a fileira de badges.
- O comportamento rígido dos badges vem de `Server/Sources/Shared/UI/Badges/DSRuntimeStatusBadge.swift`, especialmente do `fixedSize(horizontal: true, vertical: false)`.
- Vale revisar se o header deve priorizar o bloco do título ou permitir wrapping/scroll/compactação controlada nos badges.
- A correção deve atacar a composição do layout, não só ajustar espaçamento visual, para evitar regressão em telas menores.

**Por que isso entra no backlog**  
Esse bug degrada muito a leitura do workspace principal quando há muitos estados exibidos ao mesmo tempo, então vale corrigir para o header continuar legível e estável.

---

## 61) Padronizar header, filtros e cards de lista nas telas

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.64`

**Descrição**  
Criar um padrão visual reutilizável para as telas do app, separando claramente o que é `screen header`, `list header`, `list filter` e `list card/row`. Hoje algumas telas usam um header completo e bem estruturado, outras usam filtros diferentes entre si, e outras ainda montam a lista de formas muito distintas, o que faz a interface parecer inconsistente e difícil de manter. A padronização precisa cobrir tanto o layout quanto a forma de compor os elementos, para que `Chats`, `Issues`, `Memories`, `Client Voice`, `Server Logs`, `Tool Browser` e outras telas compartilhem a mesma linguagem visual.

**Dependências**  
- `44) Padronização visual das listas e master-detail no app`
- `59) Corrigir compressão do header quando os badges ocupam muito espaço`

**Comportamento desejado**  
- Separar um `screen header` comum, com título, subtítulo e ações globais da tela.
- Separar um `list header` para a área de filtros, contadores e controles da listagem.
- Separar um `list filter` reutilizável para filtros segmentados, selects e combos quando fizer sentido.
- Separar um `list card/row` com estrutura previsível para ícone, título, conteúdo, badges e ações.
- Reduzir o uso de componentes SwiftUI soltos diretamente dentro das telas principais, preferindo Views do Design System ou wrappers específicos da feature.
- Uniformizar o visual entre `Chats`, `Issues`, `Memories`, `Client Voice`, `Server Logs` e `Tool Browser` sem forçar todas as telas a terem exatamente o mesmo comportamento.

**Notas técnicas**  
- O ponto de entrada mais visível hoje está em `Server/Sources/Features/CommandCenter/Views/CommandCenterHeaderView.swift`, que precisa continuar como referência de `screen header`, mas sem esmagar o conteúdo quando os badges ocupam espaço.
- O comportamento rígido de alguns badges vem de `Server/Sources/Shared/UI/Badges/DSRuntimeStatusBadge.swift`; ele precisa ser flexível o suficiente para caber dentro do novo padrão.
- `Server/Sources/Features/Issues/Screens/IssuesScreen.swift` já mostra um `Picker` segmentado que pode servir como referência de `list filter`.
- `Server/Sources/Features/CommandCenter/Views/CommandCenterSidebar.swift` e `Server/Sources/Features/ToolsBrowser/Views/MCPToolsSidebar.swift` indicam que a navegação e o header ainda não estão completamente padronizados.
- O ideal é criar componentes base no Design System ou em uma camada shared, e depois migrar as telas para esses blocos aos poucos.

**Regra de lint desejada**  
- Adicionar um linter/regra de revisão para bloquear `import SwiftUI` fora de arquivos permitidos.
- Permitir `SwiftUI` apenas em arquivos com sufixo `View` ou dentro de `screens/Components`.
- Forçar cada feature visual a ter uma pasta `screens/Components` para seus blocos visuais reutilizáveis.
- Quando uma tela precisar de composição especial, ela deve declarar uma View própria da feature, em vez de montar tudo inline na `Screen`.
- Se a feature estiver reutilizando algo que já existe em outra feature ou que é genérico, ela deve procurar primeiro no Design System.
- A regra deve ajudar a impedir novos layouts inconsistentes antes que eles cheguem à UI.

**Arquitetura desejada**  
- Toda feature visual deve documentar seu padrão em um `Architecture.md` próprio quando houver composição relevante.
- Toda `Screen` deve usar componentes da pasta `screens/Components` ou componentes compartilhados do Design System.
- Cada linha de listagem deve virar um componente explícito, mesmo quando a lista for simples.
- Os cabeçalhos, filtros e botões também devem viver em componentes próprios quando houver repetição ou risco de divergência.
- `Screen` deve orquestrar a tela; `Components` deve carregar o visual; `Architecture.md` deve registrar essa divisão para a feature.

**Por que isso entra no backlog**  
Isso melhora bastante a consistência da aplicação inteira, reduz retrabalho visual e cria uma base mais sólida para novas telas e filtros sem cada feature inventar seu próprio padrão.

---

## 62) Padronizar o uso do Application Support por profile e feature

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Revisar e padronizar toda a forma como o app grava arquivos no `Application Support`, porque hoje cada feature parece salvar em um lugar diferente e com convenções próprias. A ideia é centralizar a regra de path e organização para que os dados fiquem previsíveis, agrupados por `profile`, depois por `profileId`, depois por `feature`, e então pelo recurso específico que aquela feature precisa salvar. Isso deve virar um padrão arquitetural único para o app inteiro, em vez de cada módulo inventar seu próprio formato.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Organizar os arquivos salvos no formato `profile/<id>/<feature>/...`.
- Garantir que cada feature grave seus dados no seu próprio espaço lógico.
- Evitar caminhos soltos, dispersos ou difíceis de rastrear dentro do `Application Support`.
- Tornar previsível onde cada feature lê e grava seus dados persistidos.
- Permitir que a estrutura seja reaproveitada por novas features sem retrabalho.

**Notas técnicas**  
- Vale criar uma classe ou um conjunto de funções estáticas gerais para montar paths, nomes de pastas e convenções de persistência.
- O foco é padronização arquitetural: cada feature deve saber exatamente onde está o seu espaço persistido.
- Esse review precisa mapear o que já existe hoje e migrar aos poucos sem quebrar os dados atuais.
- Se houver dados legados em locais diferentes, a regra nova deve prever migração ou compatibilidade temporária.
- O resultado final precisa facilitar manutenção, debug e onboarding de novas features.

**Por que isso entra no backlog**  
Isso reduz bagunça de persistência, evita inconsistência entre features e deixa a estrutura de arquivos do app muito mais fácil de manter e entender.

---

---

## 64) Recalcular data/hora e `listOrder` das mensagens no crawl

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.45`

**Descrição**  
Revisar a forma como as mensagens do WhatsApp são ordenadas e persistidas durante o crawl para evitar que mensagens mais antigas acabem sendo cadastradas como se fossem mais recentes só porque chegaram depois no processo de extração. O problema acontece quando o WhatsApp ainda está carregando mensagens antigas de baixo para cima e o crawler encontra essas mensagens fora da ordem temporal ideal. Esse item precisa consolidar a regra correta de data/hora no `ChatMessage`, recalcular `listOrder` com base na ordem real observada e garantir que o reprocessamento das mensagens deixe a timeline coerente.

**Dependências**  
- `40) Revisar ordenação real da lista de chats com inferência contextual`

**Comportamento desejado**  
- Trabalhar somente no modelo `ChatMessage`, sem alterar o modelo `Chat`.
- Recalcular `dateTime` das mensagens com a regra: primeiro `authorDate`, depois mensagens vizinhas mais próximas, e por último o timestamp de crawling como fallback final.
- Preservar a hora exata observada no crawl quando o dia precisar ser inferido por mensagens vizinhas.
- Reprocessar as mensagens para que a ordem temporal final fique coerente com o que foi realmente encontrado no chat.
- Quando o crawl encontrar mensagens fora da sequência ideal, corrigir a posição temporal delas sem depender da ordem em que foram persistidas.
- Recriar os dados do zero se necessário, sem manter estratégia legacy ou migração de compatibilidade.

**Notas técnicas**  
- O TODO atual está dentro de `Server/Sources/Features/WhatsAppCrawling/Orchestration/WhatsAppChatCrawlingOrchestrator.swift`, no fluxo de enriquecimento de mensagens já existentes.
- O bug nasce quando o WhatsApp ainda não carregou tudo e mensagens antigas entram depois, então o crawler precisa usar a ordem de observação + inferência de vizinhança para corrigir o resultado final.
- Como a hora sempre é capturada com mais confiança, o refactor deve separar claramente a inferência da data do preenchimento da hora.
- O item deve incluir a revisão do ponto em que `listOrder` e `dateTime` são persistidos para não depender da ordem de chegada do crawl.
- Não deve haver fallback “compatível com legado”; a ideia é resetar e regravar os dados já com a estrutura corrigida.

**Por que isso entra no backlog**  
Esse bug distorce a timeline das mensagens e pode fazer o assistente tratar coisa antiga como recente, então ele precisa ser corrigido na base para a ordenação voltar a refletir a realidade do chat.

---

## 65) Adicionar campo `extraction` em `ChatMessage`

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R3 - Médio`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.57`

**Descrição**  
Adicionar um novo campo estrutural em `ChatMessage` chamado `extraction` para guardar o dado extraído da mensagem separadamente do texto original. Hoje, quando uma imagem ou outra mídia vem acompanhada de texto extraível, parte dessa informação acaba sendo misturada ou perdida no fluxo atual. O objetivo é preservar o conteúdo extraído de forma explícita, sem depender apenas de sobrescrever `text`, para que a mensagem possa carregar tanto o conteúdo original quanto o conteúdo derivado da extração.

**Dependências**  
- `55) Extrair imagem em alta resolução na mensagem`
- `56) Incluir imagens no contexto de IA durante o tool calling`
- `60) Persistir hash da imagem para deduplicar extração de texto`

**Comportamento desejado**  
- Guardar o texto ou dado extraído em um campo separado de `text`.
- Preservar a mensagem original mesmo quando houver enriquecimento por OCR ou parsing de mídia.
- Permitir que imagens com texto junto mantenham tanto o conteúdo visual quanto o conteúdo textual derivado.
- Evitar perda de informação quando a extração vier junto com a mídia.
- Manter esse campo disponível para usos futuros de busca, contexto e reprocessamento.

**Notas técnicas**  
- O campo deve viver no modelo `ChatMessage`, porque a extração faz parte do conteúdo persistido da mensagem e não só de um enriquecimento transitório.
- O ideal é que `text` continue representando o texto original/visível, enquanto `extraction` armazena o material derivado da mídia ou do parser.
- Vale revisar os pontos de crawl, persistência e renderização para decidir quando usar o conteúdo original e quando usar o conteúdo extraído.
- Esse item também ajuda a preparar o sistema para futuros fluxos multimodais, sem depender de sobrecarregar `text` com tudo ao mesmo tempo.

**Por que isso entra no backlog**  
Isso evita perda de informação quando a mensagem traz texto embutido na mídia e deixa a modelagem mais clara para o resto do sistema consumir depois.

---

## 66) Associar contexto/memórias a um chat ou pessoa via MCP tool

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R2 - Baixo`
Score de Execução: `0.53`

**Descrição**  
Criar uma MCP tool para salvar um campo textual durável dentro do próprio `Chat`, algo como `chatContext`, `contextInfo` ou nome equivalente. Esse campo é uma string grande de contexto sobre aquela conversa e sobre quem aquela pessoa ou grupo representa: relação com o cliente, instruções de comunicação, histórico relacional útil, identidade do contato e notas operacionais estáveis. A ideia é que, ao listar mensagens, a IA receba junto esse contexto do chat para não depender só da sequência recente de mensagens.

**Dependências**  
- `37) Memórias categorizadas e `list_memories` filtrável`
- `40) Revisar ordenação real da lista de chats com inferência contextual`

**Comportamento desejado**  
- Permitir anexar contexto durável a um chat específico.
- Permitir que a IA associe contexto durável a uma pessoa/conversa durante o uso normal.
- Fazer `list_chat_messages` trazer também o contexto relevante daquele chat, junto do `readReceipt`.
- Manter esse contexto disponível para o runtime sem misturar com a mensagem em si.
- Permitir atualização progressiva desse contexto ao longo do tempo.
- A atualização deve escrever só esse campo contextual no repositório, sem regravar ou alterar outros campos do chat.

**Nomes possíveis para a MCP tool**  
- `add_chat_context_info`
- `append_chat_context`
- `save_chat_context`
- `add_chat_memory`
- `attach_chat_context`

**Notas técnicas**  
- O vínculo deve ser explícito por `chatId`.
- O contexto precisa ser persistido de forma durável, não apenas em memória do runtime.
- A tool deve aceitar uma string livre suficientemente grande para guardar instruções, relacionamento, identidade e nuances de comunicação.
- Esse campo é contexto do chat/pessoa, não timeline operacional da issue.
- `list_chat_messages` deve expor esse campo de forma clara para o modelo, separado do corpo das mensagens.

**Por que isso entra no backlog**  
Isso dá ao assistente uma camada de memória relacional por chat/pessoa, deixando o atendimento mais inteligente e consistente ao reconhecer quem é cada interlocutor.

---

## 67) Reforçar no prompt a prevenção de issues duplicadas

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R2 - Baixo`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.71`

**Descrição**  
Ajustar o prompt operacional para deixar explícito que o agente não deve criar várias issues para a mesma situação. Antes de abrir uma nova issue, ele deve revalidar o contexto do chat, as issues já abertas e o estado atual da conversa para confirmar se aquilo já não existe em andamento. A mesma regra deve valer antes de `send_message` e de qualquer ação repetida: o agente precisa revisar o histórico do chat para não entrar em ciclo de duplicação ou reenviar conteúdo que já foi tratado. O prompt também precisa proibir invenção de fatos: o agente só pode afirmar o que foi lido nas mensagens, nas issues, nas memórias ou em ferramentas reais, sem completar lacunas com suposições.

**Dependências**  
- `66) Associar contexto/memórias a um chat ou pessoa via MCP tool`
- `4) Ações de handled por mensagem e em lote no chat`

**Comportamento desejado**  
- Instruir o agente a checar issues já abertas antes de criar uma nova.
- Instruir o agente a reler o contexto do chat antes de enviar mensagem.
- Reduzir a chance de entrar em loop de duplicação de issue ou mensagem.
- Deixar claro no prompt que uma mesma situação não deve gerar múltiplos registros paralelos.
- Reforçar a necessidade de respeitar o histórico e o estado atual antes de agir.
- Proibir o agente de inventar datas, intenções, compromissos ou confirmações não presentes no contexto real.

**Notas técnicas**  
- O ajuste principal deve viver no `system prompt` e nos trechos de bootstrap/contexto operacional que alimentam a sessão.
- O prompt precisa mencionar explicitamente a ordem de decisão: ler contexto, validar histórico, checar issues abertas, só então criar ou enviar.
- Essa regra deve ser curta, direta e difícil de interpretar errado.
- Vale revisar também se os trechos de pending work e wait events não estão empurrando o modelo para reabrir o mesmo assunto sem necessidade.
- O texto do prompt deve deixar claro que “não saber” é preferível a adivinhar.

**Por que isso entra no backlog**  
Isso reduz duplicação, evita retrabalho operacional e deixa o assistente mais confiável ao agir sobre o mesmo assunto apenas uma vez.

---

## 68) Suspensão de issues por chat, data e alarme

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R3 - Médio`
Score de Execução: `0.46`

**Descrição**  
Reforçar e consolidar a lógica de suspensão de issues para que uma issue possa ficar suspensa até um chat ser reativado por nova mensagem, até uma data específica chegar, ou até um alarme/scheduler disparar um evento do sistema. A suspensão não deve ser apenas um estado visual: ela precisa virar um mecanismo operacional que acorda automaticamente quando o gatilho correto acontecer. Isso também precisa conversar com o `wait_for_event`, para que a suspensão seja uma fonte real de wake event.

**Dependências**  
- `58) Suspensão de issues por tempo ou por chat`
- `30) Gmail, Calendar e alarmes de subject com wake events`
- `42) wait_for_event com fontes de evento ampliadas`

**Comportamento desejado**  
- Suspender uma issue até uma data/hora específica.
- Suspender uma issue até um chat receber nova mensagem.
- Suspender uma issue até um alarme/scheduler local disparar.
- Gerar evento claro quando a suspensão terminar.
- Integrar esse desbloqueio ao fluxo de `wait_for_event`.
- Manter rastreabilidade do motivo da suspensão e do motivo do desbloqueio.

**Notas técnicas**  
- O sistema precisa de uma API/serviço de alarme ou scheduler persistido para acordar o runtime no horário certo.
- A lógica deve conversar com o modelo de `Issue`, com a timeline e com o mecanismo de eventos do runtime.
- O ideal é que o gatilho de reativação seja explícito, para que a IA saiba por que aquela issue voltou a ser relevante.
- Essa feature precisa evitar ambiguidade entre suspensão por prazo, suspensão por chat e suspensão por evento do sistema.

**Por que isso entra no backlog**  
Isso fecha a parte de orquestração temporal do assistente e deixa a suspensão de issues realmente útil para pausar trabalho até a hora ou o evento certo.

---

## 69) Tooling para copiar conteúdo para o clipboard

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R2 - Baixo`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.57`

**Descrição**  
Criar uma MCP tool para colocar texto no clipboard do sistema, como se o assistente tivesse dado `Ctrl+C` para copiar um conteúdo pedido pelo usuário. A intenção é permitir que o assistente copie códigos de verificação, e-mails, trechos de texto ou qualquer outro conteúdo útil para a área de transferência, sem depender de o usuário selecionar e copiar manualmente.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Permitir que o assistente escreva um texto no clipboard do sistema.
- Funcionar como uma ação explícita do runtime, não como efeito lateral escondido.
- Ajudar fluxos como copiar código de verificação, e-mail, endereço, número ou trecho útil.
- Manter o conteúdo copiado disponível para o usuário colar imediatamente depois.

**Notas técnicas**  
- A tool deve deixar claro que está sobrescrevendo o clipboard atual.
- O contrato deve ser simples o suficiente para ser usado por outras features sem espalhar lógica de clipboard pela codebase.
- Vale pensar em registrar o conteúdo copiado em logs de debug com cuidado, se isso não expuser informação sensível.
- O ideal é integrar com a API nativa do sistema para copiar texto sem depender de automação visual.

**Por que isso entra no backlog**  
Isso fecha uma ponta útil da operação do assistente, deixando ele capaz de preparar conteúdo para o usuário colar rapidamente quando for preciso.

---

## 70) `Speak to Client` deve sugerir `Ask to Client` quando houver pergunta

Valor: `V4 - Alto`
Risco de Desenvolvimento: `R2 - Baixo`
Risco da Feature: `R1 - Baixíssimo`
Score de Execução: `0.57`

**Descrição**  
Fazer com que a tooling `Speak to Client` sempre inclua um hint para o modelo sobre usar `Ask to Client` quando a fala enviada ao cliente contiver uma pergunta explícita. A regra só deve disparar quando o texto tiver ponto de interrogação, para evitar instruções desnecessárias em mensagens puramente informativas. A ideia é orientar o assistente a não depender apenas de fala passiva quando ele precisar realmente de uma resposta do usuário.

**Dependências**  
- `48) Componentes reutilizáveis de voz e request do cliente - doing`
- `67) Reforçar no prompt a prevenção de issues duplicadas`

**Comportamento desejado**  
- Detectar presença de `?` no texto antes de executar `Speak to Client`.
- Quando houver pergunta, adicionar um hint claro orientando o uso de `Ask to Client` para obter resposta.
- Não adicionar o hint quando a mensagem for apenas informativa.
- Manter o comportamento discreto e automático, sem poluir mensagens que não são interrogativas.

**Notas técnicas**  
- O ideal é que a regra seja aplicada no contrato/prompt da tool, não em cada chamada manual.
- A checagem do `?` deve ser simples e previsível.
- O hint precisa ser curto e direto, para não competir com o texto principal enviado ao cliente.
- Vale garantir que essa orientação não crie loops artificiais entre falar e perguntar.

**Por que isso entra no backlog**  
Isso ajuda o assistente a escolher melhor entre falar e perguntar, reduzindo o risco de mandar uma fala que deveria ter virado uma pergunta formal ao usuário.

---

## 71) Filtro central de dados sensíveis para UI, HTML e crawl

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.41`

**Descrição**  
Criar uma camada central de ofuscação/filtragem de dados sensíveis para que qualquer string exibida na interface ou processada a partir do HTML passe por uma proteção única antes de aparecer na tela. A ideia é impedir que informações sensíveis vazem em qualquer superfície visual do app, incluindo telas, listas, detalhes, previews e resultados de crawling. Tudo o que entrar no pipeline de UI ou vier do HTML deve ser analisado por essa camada e ofuscado quando necessário, para manter o conteúdo sensível sempre protegido.

**Dependências**  
- `Nenhuma`

**Comportamento desejado**  
- Passar toda string exibida na UI por uma camada central de filtro/ofuscação.
- Ofuscar dados sensíveis antes de renderizar qualquer tela.
- Aplicar a mesma proteção também ao conteúdo vindo do HTML/crawling.
- Garantir que dados sensíveis não apareçam por acidente em listas, cards, headers ou previews.
- Tornar a proteção consistente em toda a aplicação, não só em pontos isolados.

**Notas técnicas**  
- O ideal é ter uma classe/utilitário único de filtragem, para não espalhar regras de anonimização pela codebase.
- Essa camada deve ser usada tanto pela renderização de UI quanto pelos fluxos de crawling/parse.
- Vale tratar isso como uma proteção transversal, não como um filtro opcional por feature.
- O comportamento precisa ser conservador o suficiente para ocultar o que é sensível sem quebrar o restante do texto.
- Se houver dados já persistidos ou HTML já extraído, o filtro deve atuar antes da exibição e antes de qualquer processamento que leve à UI.

**Por que isso entra no backlog**  
Isso reduz muito o risco de exposição acidental de informações sensíveis e cria uma base mais segura para toda a experiência do assistente.

---

## 72) Investigar reinício de sessão sem `wait_for_event`

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.43`

**Descrição**  
Investigar um bug em que a sessão da IA parece finalizar do nada e começar outra sem que o `wait_for_event` tenha sido chamado. O comportamento esperado é que a sessão só reinicie quando o runtime atingir um boundary claro, mas hoje aparentemente existe um reset inesperado que faz o agente perder continuidade e recomeçar sozinho. Esse item é para localizar a causa real desse restart espúrio e corrigir a lógica de ciclo para que o runtime só reinicie quando realmente houver um gatilho válido.

**Dependências**  
- `42) `wait_for_event` com fontes de evento ampliadas`
- `67) Reforçar no prompt a prevenção de issues duplicadas`

**Comportamento desejado**  
- Identificar por que a sessão está reiniciando sem o boundary esperado.
- Garantir que o restart só aconteça quando houver um evento ou término de ciclo legítimo.
- Evitar perda de contexto por reinício inesperado.
- Diferenciar claramente fim de ciclo, correção de prompt e reinício indevido.
- Registrar o motivo real de qualquer reinício para facilitar debug futuro.

**Notas técnicas**  
- O bug pode estar no fluxo de runtime/cycle management, no `wait_for_event`, em correções de prompt ou em um boundary mal detectado.
- Vale inspecionar logs, estados de ciclo e transições entre requests antes de assumir a causa.
- O ideal é que o diagnóstico deixe explícito se o restart está vindo do loop principal, de uma correção automática ou de um encerramento de sessão mascarado.
- Esse item deve ser tratado como investigação antes de qualquer refactor grande.

**Por que isso entra no backlog**  
Esse tipo de reinício inesperado quebra a continuidade do assistente e pode fazer ele perder contexto ou repetir trabalho, então vale resolver na raiz.

---

## 73) Reter contexto do AIConnection entre sessões e validar boundaries de fechamento

Valor: `V5 - Altíssimo`
Risco de Desenvolvimento: `R4 - Alto`
Risco da Feature: `R4 - Alto`
Score de Execução: `0.44`

**Descrição**  
Rever as regras de perda de contexto do `AIConnection` para que o runtime não descarte tudo a cada boundary errado. Hoje o contexto costuma sumir quando a sessão reinicia, o que dificulta debug e também faz a timeline interna perder o que aconteceu antes do restart. O comportamento desejado é preservar o contexto entre sessões até que exista um fechamento legítimo, especialmente quando a execução realmente terminou um ciclo completo; nesse caso, a limpeza pode acontecer. O item também precisa investigar a inconsistência de `session completed`, que às vezes aparece sem um `wait_for_event` claro e às vezes surge depois de falha de tool, quando o esperado é que o encerramento só ocorra em boundary válido.

**Dependências**  
- `72) Investigar reinício de sessão sem `wait_for_event`

**Comportamento desejado**  
- Preservar o contexto de debug do `AIConnection` entre reinícios indevidos.
- Limpar contexto apenas quando um ciclo terminar de forma legítima.
- Evitar perder o histórico da última sessão quando ela reiniciar.
- Garantir que `session completed` só apareça em boundaries válidos e compreensíveis.
- Tornar visível o motivo real de um restart ou de um fechamento de sessão.

**Notas técnicas**  
- O inspector de `AIConnection` precisa guardar o rastro da sessão anterior para análise, mesmo quando a próxima sessão começar.
- O ciclo de vida da sessão deve distinguir claramente entre `wait_for_event`, falha de tool, correção de prompt e término real.
- Vale revisar os pontos que limpam `state.promptSections`, `conversationMessages` e eventos de debug para não zerar contexto cedo demais.
- O objetivo aqui não é só observar os logs, mas preservar contexto suficiente para entender por que a sessão caiu e o que levou ao restart.

**Por que isso entra no backlog**  
Isso melhora muito a capacidade de debug e reduz a chance de o assistente “esquecer” o que aconteceu entre uma sessão e outra sem motivo real.
