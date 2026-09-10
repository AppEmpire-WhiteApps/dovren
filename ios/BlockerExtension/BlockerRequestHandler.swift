import SafariServices

/// Supplies Safari with Dovren's bundled recipe-reading filter rules.
final class RecipeShieldRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        guard let ruleListURL = Bundle.main.url(
            forResource: "BlockerList",
            withExtension: "json"
        ) else {
            context.cancelRequest(
                withError: NSError(
                    domain: "app.hairai.dovren.recipe-shield",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Recipe shield rules are missing."
                    ]
                )
            )
            return
        }

        let rulesAttachment = NSItemProvider(contentsOf: ruleListURL)
        let response = NSExtensionItem()
        response.attachments = [rulesAttachment].compactMap { $0 }
        context.completeRequest(returningItems: [response])
    }
}
