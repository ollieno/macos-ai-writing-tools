# AiTools - macOS Text Processing via AI

## Overzicht

AiTools is een macOS-app (Swift/SwiftUI) die tekst in elke applicatie kan verwerken via AI. De gebruiker selecteert tekst, kiest via het rechtermuisklik Services-menu "Verwerk met AiTools", en krijgt een popup met voorgedefinieerde en vrije tekstbewerkingen. De verwerking gebeurt via de Claude Code CLI (`claude -p`), zodat het bestaande Claude Code Max abonnement wordt benut.

## Kernfunctionaliteit

- Rechtermuisklik-integratie via macOS Services
- Popup-venster met gegroepeerde acties uit een prompt library
- Vrij tekstveld voor eigen prompts
- Tekst wordt direct vervangen na verwerking
- Menubalk-icoon voor snelle toegang en instellingen

## Architectuur

```
Tekst selectie in app
    → Services menu → "Verwerk met AiTools"
    → Popup verschijnt (gegroepeerde acties + vrij tekstveld)
    → Gebruiker kiest actie
    → Claude Code CLI verwerkt tekst
    → Resultaat vervangt originele selectie
```

### Componenten

| Component | Verantwoordelijkheid |
|---|---|
| **AppDelegate** | Registreert de app als Services-provider bij macOS |
| **ServiceProvider** | Ontvangt geselecteerde tekst via `NSPasteboard`, opent de popup |
| **PopupWindow** | SwiftUI venster met gegroepeerde acties en vrij tekstveld |
| **PromptLibrary** | Leest de mappenstructuur, bouwt het menu op, laadt prompt-inhoud |
| **ClaudeCodeBridge** | Voert `claude -p` uit als `Process`, vangt stdout op, geeft resultaat terug |
| **MenuBarExtra** | Statusbar-icoon voor snelle toegang en instellingen |

### Flow

1. Gebruiker selecteert tekst in een willekeurige app
2. Rechtermuisklik → Services → "Verwerk met AiTools"
3. macOS stuurt geselecteerde tekst naar AiTools via `NSPasteboard`
4. AiTools toont popup-venster bij de muiscursor
5. Popup toont gegroepeerde acties (geladen uit prompt library) plus vrij tekstveld
6. Gebruiker klikt op een actie of typt een eigen prompt
7. AiTools laadt de prompt uit het `.md`-bestand, vervangt `{{text}}` met de geselecteerde tekst
8. De samengestelde prompt wordt naar `claude -p` gestuurd als subprocess
9. Het resultaat wordt teruggeschreven naar de `NSPasteboard`
10. macOS vervangt de originele selectie met het resultaat

## Prompt Library

### Mappenstructuur

```
~/Library/Application Support/AiTools/prompts/
├── Correctie/
│   └── Corrigeer spelling.md
├── Vertaling/
│   ├── Vertaal naar Engels.md
│   └── Vertaal naar Nederlands.md
└── Stijl/
    ├── Maak korter.md
    ├── Maak formeler.md
    ├── Maak informeler.md
    └── Vat samen.md
```

### Conventies

- Mapnaam = categorienaam in de popup
- Bestandsnaam zonder `.md` = actienaam in de popup
- Inhoud van het `.md`-bestand = de prompt met `{{text}}` als placeholder
- De app herlaadt de map bij elke popup-activatie (hot reload)
- Geen hercompilatie nodig voor nieuwe prompts
- Ongeldige bestanden (leeg, geen `{{text}}`, binair) worden genegeerd met een log-waarschuwing

### Vrij tekstveld prompt-compositie

Bij het vrije tekstveld wordt de prompt als volgt samengesteld:

```
<gebruiker-instructie>

{{text}}
```

De getypte instructie wordt dus direct gevolgd door de geselecteerde tekst, zonder extra wrapper.

### Voorbeeld prompt (`Corrigeer spelling.md`)

```markdown
Corrigeer alle spelling- en grammaticafouten in de volgende tekst.
Behoud de originele toon en stijl. Geef alleen de gecorrigeerde tekst terug,
zonder uitleg.

{{text}}
```

## UI Ontwerp

### Popup Window

- Gegroepeerd ontwerp: categorieen als headers, acties als knoppen
- Vrij tekstveld onderaan met "Ga" knop
- Verschijnt bij de muiscursor
- Donker thema, past bij macOS-stijl
- Geen icoontjes, alleen tekst
- Loading indicator tijdens verwerking

### MenuBar Extra

- Statusbar-icoon in de macOS menubalk
- Toegang tot instellingen
- Snelle toegang tot prompt library map

## Technische Details

### Services-registratie

- Via `NSApplication.shared.servicesProvider`
- `Info.plist` entry definieert het service-item
- Service ontvangt `NSPasteboard.PasteboardType.string` (modern API)

### Claude Code CLI Bridge

- Asynchroon via Swift `Process` class
- Prompt wordt via **stdin** naar het process gestuurd (niet als command-line argument, vanwege shell-escaping, ARG_MAX limieten, en zichtbaarheid via `ps`)
- Commando: `claude -p` met prompt op stdin
- Stdout wordt opgevangen als resultaat
- Timeout: 120 seconden (configureerbaar)
- Pad naar `claude` binary: zoekt in `$PATH` vanuit een login shell, bekende locaties (`/usr/local/bin`, `~/.claude/bin`, Homebrew paden). Gebruiker kan pad handmatig instellen via instellingen.

### Popup-positionering en gedrag

- Verschijnt bij `NSEvent.mouseLocation`
- Blijft binnen schermgrenzen
- Escape of klik buiten de popup sluit zonder actie (originele tekst blijft ongewijzigd)
- Popup is modaal: een tweede aanroep terwijl er al een actief is, wordt genegeerd
- Na verwerking keert focus terug naar de oorspronkelijke app

### Error Handling

- Claude CLI niet gevonden: melding met installatie-instructies
- CLI fout: originele tekst behouden, foutmelding tonen
- Timeout: melding tonen, originele tekst behouden
- Services text replacement niet ondersteund door bron-app: resultaat wordt op het klembord geplaatst met een notificatie ("Resultaat gekopieerd naar klembord")

### Sandboxing en distributie

- De app draait **zonder sandbox** (vereist subprocess-uitvoering en toegang tot `~/Library/Application Support`)
- Distributie buiten de App Store (direct download of Homebrew)
- Notarization wordt overwogen voor toekomstige releases

### Eerste keer starten

- Bij eerste lancering maakt de app de prompts-map aan (`~/Library/Application Support/AiTools/prompts/`)
- De standaard prompt-set (7 prompts in 3 categorieen) wordt als seed-bestanden aangemaakt
- Gebruiker krijgt een welkomstmelding met uitleg over de Services-integratie

## Eerste release (scope)

- Services-integratie met een enkel menu-item
- Popup met gegroepeerde acties uit prompt library
- Vrij tekstveld
- Claude Code CLI bridge
- Standaard prompt-set (7 prompts in 3 categorieen)
- Menubalk-icoon met link naar prompts-map

## Buiten scope (toekomstig)

- Keyboard shortcut integratie
- Preview-venster met diff
- Prompt-editor in de app zelf
- Meerdere AI-providers
- Prompt sharing/import
