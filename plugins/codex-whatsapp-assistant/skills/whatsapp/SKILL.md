<skill>
<name>whatsapp</name>
<description>Controla o WhatsApp Desktop via o MCP Server local configurado pelo plugin.</description>
</skill>

# WhatsApp (via MCP)

Use este skill quando você quiser enviar/ler mensagens no WhatsApp Desktop usando o MCP Server local.

## Pré-requisitos

- WhatsApp Desktop aberto.
- Assistant MCP Server rodando e acessível em `http://localhost:8080/mcp` (ou a URL definida em `plugins/codex-whatsapp-assistant/.mcp.json`).

## Ferramentas disponíveis (via MCP local)

- `list_chats()`: lista chats disponíveis.
- `list_unread_chats()`: lista chats com mensagens não lidas.
- `get_recent_messages(chatId, limit)`: lê as mensagens mais recentes de um chat para contexto.
- `wait_for_message(chatId?, afterMessageId?)`: aguarda nova mensagem (long-poll) sem polling agressivo.
- `send_message(chatId, text | messages[])`: envia mensagem (texto único) ou lista de mensagens curtas.
- `list_nicknames(chatId?)`: lista apelidos salvos (global ou por chat, dependendo do servidor).
- `save_nickname(chatId, nickname, chatName?)`: salva um apelido para um chat (ex.: “mãe”, “namorado”, “Léo”).
- `delete_nickname(id)`: remove um apelido salvo.
- `speak_to_client(text, ...)`: anuncia algo por voz para o cliente.
- `ask_to_client(prompt, ...)`: pergunta algo por voz para o cliente e aguarda resposta.

## Exemplos de pedidos

- “Envie ‘chego em 10 min’ para o João.”
- “Liste minhas mensagens não lidas e resuma.”
- “Busque a última mensagem no chat ‘Família’.”

## Padrões recomendados

- Resolução por apelido:
  - quando o cliente usar termos como “mãe”, “meu namorado”, “Léo”, prefira `list_nicknames()` para achar o `chatId`.
  - se não existir apelido, procure por nome em `list_chats()` e ofereça salvar com `save_nickname(...)`.
- Envio com mais naturalidade:
  - prefira `send_message(chatId, messages=[...])` com 2–4 mensagens curtas (saudação / contexto / pergunta / fechamento).
- Segurança:
  - antes de enviar algo sensível (dinheiro, dados pessoais, cancelamentos, confirmações), confirme com o cliente usando `ask_to_client(...)` (voz) quando possível.
