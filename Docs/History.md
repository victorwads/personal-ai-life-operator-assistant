# Project History

This document tells the story of how this project came to be and how its shape changed over time.

## 1. The original need

The root problem was not technical at first. Life was getting crowded by work, health issues, and everyday admin, and the things that mattered most kept getting pushed aside.

Medical logistics were a recurring pain point. Calling health insurance, finding a doctor, and scheduling an appointment could easily eat up hours of the day. Phone numbers were stale, web listings were incomplete, and every step required manual follow-up across calls and WhatsApp messages.

## 2. Hiring a human assistant

At one point, I had enough money to pay a friend to help for about an hour a day. The work was not glamorous, but it was valuable: organizing email and calendar, reminding me of appointments, and nudging me to act when something important was coming up.

That arrangement helped, but it also showed the limits of a small human support loop. The assistant could not realistically keep up with everything, and eventually I no longer had the budget to maintain that setup.

## 3. Looking for software assistance

After that, I started looking for a way to make the assistant behavior more durable and less dependent on constant human effort.

I was already using Codex a lot, and at the time it began to support Gmail and Calendar integrations. I connected it to my workflow and asked it to help me with email and scheduling tasks.

That worked reasonably well for simple things, like reading messages and categorizing them, but it was expensive. Even small tasks could consume a big chunk of usage.

## 4. The WhatsApp bottleneck

WhatsApp became the next obvious target.

The reasoning was simple: if the assistant could handle the WhatsApp side locally, it would reduce the amount of model time spent on repetitive reading, categorization, and reply preparation.

At first the idea was to let the model interact directly with the WhatsApp Desktop app through Accessibility. That worked, but it was expensive in tokens and cognitively heavy for the model, because it had to understand the native app layout and keep track of the interface on its own.

That was the point where the project stopped being “a bot that sends messages” and became more like “a local assistant runtime that exposes WhatsApp actions through a cleaner API.”

## 5. The MCP server phase

The first concrete implementation was an MCP server for WhatsApp.

The idea was to give the model a smaller set of tools:

- list chats
- select a chat
- read messages
- send messages

That reduced the amount of work the model had to do and made the workflow more structured.

This is where the project began as `AssistantMCPServer`.

## 6. The cost problem and the LM Studio turn

There was another major turning point.

The cloud-based setup still cost too much for sustained use. A simple model loop could spend a surprising amount of quota, and that made the whole system fragile for day-to-day life.

The reminder from my partner was basically: the intelligence layer itself could be local and cheap if I moved the runtime to my own machine.

That led me back to LM Studio.

I had not used it seriously for quite a while, but local models had changed a lot. On my M3 Max machine, local reasoning had become fast enough to be useful in practice. I tested it with the WhatsApp workflow and it worked much better than I expected.

That is when the project became a local assistant runtime instead of a cloud-dependent interaction.

## 7. Memory and sensitive data

Once the assistant could work locally, it needed memory.

It also needed a safer way to handle private information. Some things, like CPFs, insurance numbers, and contact details, are not general memory and should not be exposed broadly.

That is what led to the `Memory` and `Sensitive Data` pieces: a split between durable knowledge, operational context, and protected personal records.

## 8. Moving from Desktop to WebView

The native WhatsApp Desktop integration started hitting friction.

The more I pushed the system, the clearer it became that relying entirely on the native desktop app was too brittle for the long term. So I introduced WhatsApp Web inside the macOS app through a WebView.

That shifted the project again:

- more control
- fewer external dependencies
- more predictable integration
- less interference from the user

At that point the macOS app was no longer just a server process. It had become an operational runtime with its own interface, its own persistence, its own tool surface, and its own integration surface.

## 9. The broader assistant runtime

As the project evolved, it started to absorb more responsibilities:

- session supervision
- LM Studio orchestration
- client voice interaction
- pending-message handling
- debug tooling
- subjects and workflows

That is why the current identity is no longer just “an MCP server.”

The project is becoming a local assistant runtime with WhatsApp as one of its core surfaces.

## 10. Where this goes next

The next chapters are likely to include:

- LM Studio session supervision from inside the app
- humanization as a separate pass from reasoning
- remote/mobile access
- richer observability over model events
- better automation around tests and restart flows

This history will keep growing as the system grows.
