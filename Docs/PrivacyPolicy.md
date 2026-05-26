# Política de Privacidade

Última atualização: 26 de maio de 2026

Esta política descreve como o AssistantMCPServer trata dados pessoais e operacionais dos usuários. O projeto é um assistente pessoal experimental com IA, criado para testes, pesquisa, uso pessoal e validação de uma experiência de assistente capaz de ajudar com conversas, memórias, assuntos da vida, dados sensíveis e tarefas do dia a dia.

O projeto não tem fins lucrativos, não vende dados pessoais e não utiliza os dados dos usuários para publicidade.

## 1. Natureza do projeto

O AssistantMCPServer ainda é um projeto em fase experimental. Ele não é, neste momento, um produto aberto ao público em geral nem um serviço comercial amplo. O acesso pode ser limitado, controlado por inscrição, convite, capacidade técnica ou disponibilidade do mantenedor.

A proposta do projeto é permitir que entusiastas e usuários convidados testem um assistente pessoal com IA em um ambiente realista, com integrações como WhatsApp, voz, memórias, dados sensíveis, assuntos de acompanhamento e ferramentas de automação.

Por estar em desenvolvimento, funcionalidades, formas de armazenamento, integrações e políticas operacionais podem mudar ao longo do tempo. Mudanças relevantes devem ser refletidas neste documento.

## 2. Compromisso com os dados do usuário

Os dados armazenados existem para que o assistente funcione para o próprio usuário. Eles não são vendidos, alugados, compartilhados para publicidade, usados para corretagem de dados ou explorados comercialmente por terceiros.

Em termos simples: se você entrega uma informação ao seu assistente para que ele lembre, organize ou use em uma tarefa, essa informação pode ser armazenada para permitir essa funcionalidade. A finalidade é assistência pessoal, continuidade e teste do sistema, não monetização dos seus dados.

## 3. Dados que podem ser coletados ou armazenados

Dependendo das funcionalidades usadas, o projeto pode coletar, processar ou armazenar:

- dados de cadastro, autenticação ou identificação necessários para uso do sistema;
- mensagens, trechos de conversas, metadados de chats e informações relacionadas ao WhatsApp quando a integração estiver ativa;
- nomes, apelidos, identificadores de contatos e preferências pessoais;
- memórias criadas pelo usuário ou pelo assistente;
- assuntos da vida do usuário, tarefas, pendências, acompanhamentos, compromissos e contexto operacional;
- dados sensíveis fornecidos pelo usuário ao assistente, como documentos, informações de saúde, dados familiares, endereços, números de convênio, informações financeiras ou outros dados confidenciais;
- histórico de interações com o assistente, incluindo comandos, respostas, solicitações e resultados de ferramentas;
- registros de voz, transcrições, respostas pendentes ou histórico de eventos de voz, quando recursos de voz forem usados;
- logs técnicos, registros de erro, eventos de integração e dados necessários para depuração e segurança;
- configurações do aplicativo, perfis, preferências e estado de execução.

O usuário deve evitar fornecer dados que não deseja que sejam armazenados ou usados pelo assistente.

## 4. Armazenamento no Firebase

Os dados do usuário podem ser armazenados no Firebase, incluindo bancos de dados, autenticação, armazenamento, logs ou outros serviços da plataforma Firebase/Google Cloud usados pelo projeto.

Isso significa que os dados podem sair do dispositivo local e ficar armazenados em infraestrutura operada pela Google, de acordo com os serviços configurados no projeto. A Google/Firebase pode processar esses dados como provedora de infraestrutura, conforme seus próprios termos, controles de segurança e políticas aplicáveis.

O Firebase é usado para permitir persistência, sincronização, acesso remoto, suporte a múltiplos perfis, operação por clientes móveis e continuidade do assistente entre sessões.

## 5. Como os dados são usados

Os dados podem ser usados para:

- permitir que o assistente lembre informações importantes para o usuário;
- organizar assuntos, pendências, tarefas, compromissos e acompanhamentos;
- ler contexto relevante e executar ações solicitadas;
- responder ou preparar respostas em conversas quando autorizado;
- manter continuidade entre sessões, dispositivos, perfis e interações;
- diferenciar memórias comuns de dados sensíveis;
- oferecer recursos de voz, ditado, leitura em voz alta e fluxo hands-free;
- depurar falhas, melhorar estabilidade, entender problemas técnicos e proteger o serviço;
- avaliar a viabilidade do projeto como experimento de assistente pessoal com IA.

Os dados não são usados para vender perfis, direcionar anúncios ou alimentar serviços de publicidade.

## 6. Dados sensíveis

O projeto pode armazenar dados sensíveis quando o usuário decide fornecê-los ao assistente ou quando esses dados são necessários para uma tarefa solicitada. O objetivo é que o assistente consiga ajudar com situações reais da vida, como saúde, documentos, convênio, família, compromissos e organização pessoal.

Esses dados devem ser tratados com cuidado. Mesmo que o projeto tenha a intenção de separar e auditar dados sensíveis, nenhum sistema é totalmente livre de risco.

Recomenda-se que o usuário:

- forneça apenas os dados necessários;
- evite enviar informações extremamente sensíveis se não forem indispensáveis;
- revise periodicamente memórias e dados salvos;
- solicite exclusão quando não quiser mais que uma informação fique armazenada;
- tenha consciência de que dados salvos no Firebase ficam em infraestrutura remota.

## 7. Compartilhamento com terceiros

O projeto não vende nem compartilha dados pessoais para fins comerciais ou publicitários.

Dados podem ser processados por terceiros apenas quando isso for necessário para a funcionalidade escolhida ou para a infraestrutura do serviço. Exemplos:

- Firebase/Google Cloud, para armazenamento, autenticação, sincronização, logs ou infraestrutura;
- WhatsApp/Meta, quando mensagens são enviadas, recebidas ou acessadas pela própria conta do usuário;
- provedores de IA, modelos locais, LM Studio ou serviços configurados para processar solicitações do assistente;
- serviços de voz, transcrição, notificações, automação ou outros recursos conectados pelo projeto ou pelo usuário;
- sistemas operacionais, navegadores e aplicativos locais envolvidos na execução das funcionalidades.

Cada terceiro pode ter seus próprios termos de uso, políticas de privacidade e práticas de retenção.

## 8. Exclusão de dados

O usuário pode excluir dados diretamente quando houver funcionalidade disponível no aplicativo ou solicitar a exclusão pelo e-mail:

contato@wads.dev

Ao receber uma solicitação, o projeto buscará excluir os dados associados ao usuário nos sistemas sob seu controle, incluindo registros armazenados no Firebase quando tecnicamente possível.

A exclusão pode não remover imediatamente:

- backups temporários;
- logs técnicos necessários por segurança, auditoria ou diagnóstico;
- dados já enviados a terceiros, como mensagens enviadas pelo WhatsApp;
- cópias mantidas pelo próprio usuário, por dispositivos, aplicativos, sistemas operacionais ou serviços externos.

Mesmo nesses casos, a intenção é reduzir e remover os dados pessoais do ambiente controlado pelo projeto sempre que o usuário pedir.

## 9. Retenção de dados

Os dados são mantidos enquanto forem necessários para o funcionamento do assistente, para a continuidade da experiência, para testes do projeto ou para obrigações técnicas e de segurança.

Como este é um projeto experimental e de acesso restrito, os critérios de retenção podem evoluir. O usuário pode solicitar exclusão a qualquer momento pelo contato indicado nesta política.

## 10. Segurança

O projeto busca proteger os dados com as práticas disponíveis na infraestrutura usada, incluindo os recursos de segurança do Firebase e controles do próprio aplicativo. Ainda assim, nenhum sistema é completamente seguro.

Riscos possíveis incluem falhas de software, configuração incorreta, acesso indevido ao dispositivo, vazamento de credenciais, comportamento inesperado de modelos de IA ou exposição por integrações externas.

Medidas recomendadas ao usuário:

- usar senha forte e proteger seus dispositivos;
- revisar quais dados entrega ao assistente;
- não compartilhar capturas, logs ou respostas do assistente sem verificar dados pessoais;
- manter aplicativos, sistema operacional e integrações atualizados;
- solicitar exclusão de dados que não devem mais permanecer no sistema.

## 11. Permissões do sistema e integrações

Algumas funcionalidades podem depender de permissões do sistema operacional ou de integrações externas, como:

- Acessibilidade do macOS, para inspecionar ou controlar interfaces locais;
- microfone e reconhecimento de fala, para recursos de voz;
- WhatsApp Web ou WhatsApp Desktop, para leitura e envio de mensagens;
- rede, notificações, autenticação e sincronização;
- clientes móveis ou interfaces remotas futuras.

Ao conceder permissões ou conectar serviços, o usuário permite que o assistente acesse os dados necessários para executar as funcionalidades correspondentes.

## 12. Limitação de usuários e disponibilidade

O projeto pode limitar a quantidade de usuários, perfis ou acessos por razões técnicas, financeiras, operacionais ou de segurança. A inscrição ou o convite não garante disponibilidade contínua, suporte permanente ou manutenção indefinida.

Por ser um experimento, o serviço pode ser pausado, alterado, migrado ou encerrado. Quando possível, o projeto deve oferecer meios razoáveis para exportar, revisar ou excluir dados antes de mudanças relevantes.

## 13. Crianças e adolescentes

O projeto não é direcionado especificamente a crianças. Se for usado por menores de idade, o responsável legal deve avaliar o uso, as permissões concedidas, os dados armazenados e as leis aplicáveis.

## 14. Alterações nesta política

Esta política pode ser atualizada conforme o projeto evoluir. A data de última atualização deve ser ajustada quando houver mudanças relevantes.

## 15. Contato

Para dúvidas, solicitações de privacidade, pedidos de exclusão ou outros assuntos relacionados a dados pessoais, entre em contato:

- E-mail: contato@wads.dev
- Projeto: AssistantMCPServer / Wads.dev

