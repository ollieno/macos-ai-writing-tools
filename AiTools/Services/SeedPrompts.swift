import Foundation

struct SeedPrompts {
    static func installIfNeeded(to directory: URL) throws {
        let fm = FileManager.default

        if fm.fileExists(atPath: directory.path) {
            return
        }

        guard let bundledURL = Bundle.main.url(forResource: "DefaultPrompts", withExtension: nil) else {
            try installFromCode(to: directory, fileManager: fm)
            return
        }

        try fm.copyItem(at: bundledURL, to: directory)
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
             "Vat de volgende tekst samen in enkele zinnen.\nGeef alleen de samenvatting terug, zonder uitleg.\n\n{{text}}")
        ]

        for prompt in prompts {
            let catDir = directory.appendingPathComponent(prompt.category)
            try fm.createDirectory(at: catDir, withIntermediateDirectories: true)
            let file = catDir.appendingPathComponent("\(prompt.name).md")
            try prompt.content.write(to: file, atomically: true, encoding: .utf8)
        }
    }
}
