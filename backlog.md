# Backlog (WhatsApp Assistant)

Arquivo em: `/Users/DevData/victorwads/GitRepos/Personal/AssistantMCPServer/backlog.md`

Instrução: antes de qualquer commit relacionado a itens deste backlog, validar que o build está funcionando usando `scripts/check_build_and_restart.sh`.

Este arquivo reúne ideias e melhorias para retomarmos depois. Cada item fica separado por uma linha `---`.

---

## 1) Encontrar chat que não aparece na lista inicial

**Descrição**  
Quando a conversa não estiver visível na lista principal do app, o agente deve conseguir pesquisar o nome ou número na barra de busca do WhatsApp Web/Desktop, validar o resultado e abrir o chat certo antes de seguir com a ação.

**Por que isso entra no backlog**  
É um fluxo mais complexo e frágil, porque depende de busca, seleção de resultado, validação de ambiguidade e sincronização do contexto do chat antes do envio.

---

## 2) Arquivar conversa

**Descrição**  
Adicionar a capacidade de arquivar uma conversa específica para manter o conjunto de chats ativos mais enxuto e organizado. O comportamento padrão do WhatsApp de reabrir o chat quando chegam mensagens novas continua valendo.

**Por que isso entra no backlog**  
É uma melhoria útil para controle de contexto e limpeza da lista de conversas, com uma implementação relativamente direta em comparação com o fluxo de busca/resolução de chat.

---

## 3) Bloqueio e desbloqueio da WebView

**Descrição**  
Adicionar um ícone de bloqueio/desbloqueio ao lado do título do WhatsApp para controlar a interação com a WebView. No modo bloqueado, a WebView fica travada para o usuário, com viewport fixo em `1080p` e mantendo `80%` de escala. No modo desbloqueado, a WebView volta a usar o tamanho disponível da janela, também com `80%` de escala.

**Comportamento desejado**  
- Mostrar um ícone de bloqueado/desbloqueado ao lado do título.
- Quando bloqueado, impedir interação do usuário com a WebView.
- Quando desbloqueado, permitir interação normal e ajustar o viewport ao tamanho da janela.
- Exibir um helper/tooltip avisando que ao desbloquear o pooling de mensagens vai parar.

**Por que isso entra no backlog**  
Isso controla melhor o modo de uso entre automação e interação manual, além de recuperar um comportamento que já existia na primeira versão.

---

## 4) Configuração de seletores via YAML com auto-update

**Descrição**  
Externalizar os seletores e IDs usados no parse do WhatsApp Web para um arquivo `YAML` versionado. Esse arquivo deve ser bundlado no app como padrão, mas o runtime pode baixar uma versão mais recente via uma URL configurável nas Settings. Se a URL estiver vazia, o app usa apenas o `YAML` embutido e não tenta atualizar.

**Regras desejadas**  
- O `YAML` precisa carregar metadados como data da versão e versão do schema.
- Enquanto a versão do schema for compatível, o app pode atualizar só o `YAML` sem exigir atualização do binário.
- Se o schema mudar, a atualização precisa ser feita no app nativo.
- Toda a lógica de parsing atual do WhatsApp Web deve deixar de depender de IDs hardcoded espalhados no código e passar a consultar essa configuração centralizada.
- O `YAML` deve permitir múltiplas alternativas por seletor, para cobrir mudanças de DOM/HTML sem quebrar o fluxo.

**Por que isso entra no backlog**  
Isso reduz o acoplamento com o HTML atual do WhatsApp Web e facilita manter o app funcionando quando a interface mudar, sem precisar lançar uma nova versão para toda alteração pequena de seletor.

---

Exemplo de prompts finais:
- Execute as alterações do item `## X) Xxxxx Xxx Xxxxx Xxxxx` do arquivo `backlog.md`.
- Pode remover do backlog e comitar as alterações e o backlog inteiro. (após permissão explicita para remover do backlog)
