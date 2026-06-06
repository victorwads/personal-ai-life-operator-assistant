import XCTest
@testable import AIAssistantHub

final class SendMessageMCPToolSupportTests: XCTestCase {
    func testMessagesExtractionFailsWhenPayloadContainsEmptyStrings() throws {
        let call = MCPToolCall(
            name: "send_message",
            arguments: [
                "issueId": .string("Mqa6MrQAz5PiaDxCE42T"),
                "chatId": .string("whatsapp-d951c84c4d86f507"),
                "messages": .array([
                    .string("Oi! Tudo bem? Aqui e o assistente do Victor. Ele aprovou o pedido de R$ 100,00 e gostaria de finalizar a encomenda com as seguintes especificacoes:"),
                    .string(""),
                    .string("• **Pizza Media (Meio a Meio):**"),
                    .string("  - Metade: Frango com Catupiry de verdade (original)."),
                    .string("  - Metade: Cinco Queijos, retirando o cheddar e incluindo Gorgonzola."),
                    .string("• **Borda Recheada:** Cream Cheese (aprovado pelo cliente)."),
                    .string(""),
                    .string("Valor total: R$ 100,00."),
                    .string(""),
                    .string("**Endereco para Entrega:**"),
                    .string("Rua Doutor Bento Vidal, no 594, Bloco Bia, Apartamento 42."),
                    .string(""),
                    .string("Podem confirmar o horario de entrega? Obrigado!")
                ])
            ]
        )

        XCTAssertThrowsError(try SentMessageMCPToolSupport.messages(from: call)) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Field `messages` is invalid: each item must be a non-empty string."
            )
        }
    }

    func testMessagesExtractionAcceptsSamePayloadWithoutEmptyStrings() throws {
        let call = MCPToolCall(
            name: "send_message",
            arguments: [
                "issueId": .string("Mqa6MrQAz5PiaDxCE42T"),
                "chatId": .string("whatsapp-d951c84c4d86f507"),
                "messages": .array([
                    .string("Oi! Tudo bem? Aqui e o assistente do Victor. Ele aprovou o pedido de R$ 100,00 e gostaria de finalizar a encomenda com as seguintes especificacoes:"),
                    .string("• **Pizza Media (Meio a Meio):**"),
                    .string("  - Metade: Frango com Catupiry de verdade (original)."),
                    .string("  - Metade: Cinco Queijos, retirando o cheddar e incluindo Gorgonzola."),
                    .string("• **Borda Recheada:** Cream Cheese (aprovado pelo cliente)."),
                    .string("Valor total: R$ 100,00."),
                    .string("**Endereco para Entrega:**"),
                    .string("Rua Doutor Bento Vidal, no 594, Bloco Bia, Apartamento 42."),
                    .string("Podem confirmar o horario de entrega? Obrigado!")
                ])
            ]
        )

        XCTAssertEqual(
            try SentMessageMCPToolSupport.messages(from: call),
            [
                "Oi! Tudo bem? Aqui e o assistente do Victor. Ele aprovou o pedido de R$ 100,00 e gostaria de finalizar a encomenda com as seguintes especificacoes:",
                "• **Pizza Media (Meio a Meio):**",
                "- Metade: Frango com Catupiry de verdade (original).",
                "- Metade: Cinco Queijos, retirando o cheddar e incluindo Gorgonzola.",
                "• **Borda Recheada:** Cream Cheese (aprovado pelo cliente).",
                "Valor total: R$ 100,00.",
                "**Endereco para Entrega:**",
                "Rua Doutor Bento Vidal, no 594, Bloco Bia, Apartamento 42.",
                "Podem confirmar o horario de entrega? Obrigado!"
            ]
        )
    }
}
