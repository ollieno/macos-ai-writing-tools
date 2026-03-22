import Foundation

struct SeedPrompts {
    static func installIfNeeded(to directory: URL) throws {
        let fm = FileManager.default

        if !fm.fileExists(atPath: directory.path) {
            if let bundledURL = Bundle.main.url(forResource: "DefaultPrompts", withExtension: nil) {
                try fm.copyItem(at: bundledURL, to: directory)
            } else {
                try installFromCode(to: directory, fileManager: fm)
            }
        }

        seedSystemPrompt(to: directory, fileManager: fm)
    }

    private static func installFromCode(to directory: URL, fileManager fm: FileManager) throws {
        let prompts: [(category: String, name: String, content: String)] = [
            ("Correctie", "Corrigeer spelling",
             "Corrigeer alle spelling- en grammaticafouten in de volgende tekst.\nBehoud de originele toon en stijl. Geef alleen de gecorrigeerde tekst terug,\nzonder uitleg.\n\n{{text}}"),
            ("Vertaling", "Vertaal naar Engels",
             "Vertaal de volgende tekst naar het Engels.\nBehoud de toon en stijl. Geef alleen de vertaling terug, zonder uitleg.\n\n{{text}}"),
            ("Vertaling", "Vertaal naar Nederlands",
             "Vertaal de volgende tekst naar het Nederlands.\nBehoud de toon en stijl. Geef alleen de vertaling terug, zonder uitleg.\n\n{{text}}"),
            ("Stijl", "Maak korter",
             "Maak de volgende tekst korter en bondiger.\nBehoud de kernboodschap. Geef alleen de verkorte tekst terug, zonder uitleg.\n\n{{text}}"),
            ("Stijl", "Maak formeler",
             "Herschrijf de volgende tekst in een formelere toon.\nGeef alleen de herschreven tekst terug, zonder uitleg.\n\n{{text}}"),
            ("Stijl", "Maak informeler",
             "Herschrijf de volgende tekst in een informelere, vriendelijkere toon.\nGeef alleen de herschreven tekst terug, zonder uitleg.\n\n{{text}}"),
            ("Stijl", "Vat samen",
             "Vat de volgende tekst samen in enkele zinnen.\nGeef alleen de samenvatting terug, zonder uitleg.\n\n{{text}}"),
            ("Afbeelding", "Beschrijf afbeelding",
             "Beschrijf de volgende afbeelding in het Nederlands.\nWees beknopt maar volledig. Geef alleen de beschrijving terug, zonder uitleg.\n\n{{image}}"),
            ("Afbeelding", "Lees tekst uit afbeelding",
             "Lees alle tekst die zichtbaar is in de volgende afbeelding.\nGeef alleen de gevonden tekst terug, zonder uitleg.\n\n{{image}}")
        ]

        for prompt in prompts {
            let catDir = directory.appendingPathComponent(prompt.category)
            try fm.createDirectory(at: catDir, withIntermediateDirectories: true)
            let file = catDir.appendingPathComponent("\(prompt.name).md")
            try prompt.content.write(to: file, atomically: true, encoding: .utf8)
        }
    }

    private static let systemPromptContent = """
        Je bent een tekstverwerkingstool. Geef ALLEEN het gevraagde resultaat terug.
        Geen inleiding, geen afsluiting, geen uitleg, geen begeleidende tekst.
        Niet beginnen met zinnen als "Hier is..." of "Dit is de...".
        Alleen het directe antwoord op de instructie, niets meer.
        """

    private static func seedSystemPrompt(to directory: URL, fileManager fm: FileManager) {
        let file = directory.appendingPathComponent("_system.md")
        guard !fm.fileExists(atPath: file.path) else { return }
        try? systemPromptContent.write(to: file, atomically: true, encoding: .utf8)
    }
}
