# Concerto

**Opus dirigiert, Sonnets spielen.**

[English](README.md) · [简体中文](README.zh-CN.md) · Deutsch

Concerto macht aus [Claude Code](https://claude.com/claude-code) eine automatische, parallele Coding-Pipeline. Du wirfst einfach weiter Ideen ein: Opus plant sie, mehrere Sonnet-Agenten setzen sie nebeneinander in isolierten Git-Worktrees um, ein unabhängiger Verifier prüft jedes Ergebnis, und am Ende wird alles zusammengeführt – ohne dass du daneben sitzen musst.

Gebaut für Menschen, deren Ideen nie aufhören (ADHS-freundlich von Anfang an): Eine Idee festzuhalten kostet einen kurzen Befehl, den ganzen Stapel abzuarbeiten einen weiteren.

```
/hum Login-Timeout beheben           # eine Zeile, sofort erledigt
/hum --json-Ausgabe für die CLI
/hum utils in drei Module aufteilen
/opus                                # Plan → parallele Umsetzung → Prüfung → Merge, vollautomatisch
```

## So funktioniert es

```
        ┌──────────────┐
Ideen → │ Opus         │  Recherche, Aufgabenkarten, Abhängigkeitsgraph
        │ (Dirigent)   │
        └──────┬───────┘
               │ startet jede Karte, deren Abhängigkeiten erfüllt sind (max. 4 gleichzeitig)
     ┌─────────┼──────────┐
     ▼         ▼          ▼
 executor   executor   executor      Sonnet, je ein Git-Worktree
     │         │          │
     ▼         ▼          ▼
 verifier   verifier   verifier      Sonnet, unabhängig, nur lesend
     └─────────┼──────────┘
               ▼ PASS → Merge nach concerto/<plan-id>, Tests laufen
        ┌──────────────┐
        │ Ausgangsbranch│  Fast-Forward nur, wenn alles grün ist
        └──────────────┘
```

- **Abhängigkeitsgesteuerte Planung.** Eine Karte startet, sobald ihre Abhängigkeiten gemergt sind – kein Warten auf eine ganze Welle. Karten, die dieselben Dateien ändern, laufen nie gleichzeitig.
- **Verifikation als Pipeline.** Jedes Executor-Ergebnis wird sofort geprüft und gemergt. Eine durchgefallene Karte wird mit den konkreten Korrekturhinweisen des Verifiers zweimal wiederholt, danach übernimmt Opus selbst.
- **Mehrere Runden.** Ideen, die du während einer Runde hinzufügst, werden automatisch in der nächsten Runde aufgegriffen – bis zu 3 Runden in Folge. So kannst du in einem zweiten Terminal weiter erfassen.
- **Fortsetzbar.** Der gesamte Zustand liegt in `.claude/work/<plan-id>/plan.md` und `log.md`; nach einer Unterbrechung macht `/da-capo` weiter.
- **Standardmäßig sicher.** Concerto pusht nie und erzwingt nie etwas (kein Force). Gearbeitet wird auf `concerto/<plan-id>`; zurückgemergt wird nur bei grünen Tests, sonst bleibt der Stand dort zur Prüfung liegen.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/opus <Anforderungen>` | Plant und führt eine oder mehrere Anforderungen (mit `;` getrennt) komplett aus. |
| `/opus` | Ohne Argumente: nimmt **alle offenen Ideen** aus dem Pool, gruppiert sie und führt unabhängige parallel aus. |
| `/hum <Idee>` | Hängt eine Idee an `.claude/work/ideas.md` an. Eine Zeile, keine Analyse. |
| `/hum` | Gruppiert offene Ideen und schlägt passende `/opus`-Befehle vor. |
| `/encore` | Übersicht aller Pläne im Projekt (Fortschritt, fehlgeschlagene oder blockierte Karten) und offener Ideen. Nur lesend. |
| `/da-capo [plan-id]` | Setzt einen Plan fort oder startet ihn neu (Standard: der jüngste unfertige). Auch nach manuellem Bearbeiten von `plan.md`. |

Ein `SessionStart`-Hook erinnert dich außerdem an unfertige Pläne und offene Ideen, sobald du in einem Projekt eine Sitzung öffnest.

## Installation

Voraussetzungen: [Claude Code](https://claude.com/claude-code), `git`, `jq`, macOS oder Linux (bash).

```bash
git clone https://github.com/<you>/concerto.git
cd concerto
./install.sh
```

Das Installationsskript kopiert zwei Agenten, vier Skills, ein Hook-Skript und eine Plan-Vorlage nach `~/.claude/` (mit `CLAUDE_HOME` lässt sich ein anderer Ort wählen), hängt einen kurzen Block an `~/.claude/CLAUDE.md` an und fügt `~/.claude/settings.json` – nach einem Backup als `settings.json.bak-concerto` – einen `SessionStart`-Hook hinzu. Bestehende Einstellungen werden nie überschrieben; mehrfaches Ausführen ist unbedenklich, ersetzte Dateien werden vorher als `*.bak-concerto` gesichert.

Entfernen mit `./uninstall.sh` (Projektdaten in `.claude/work/` und die Backups bleiben erhalten).

Starte `/opus` am besten in einer **Opus**-Sitzung für die beste Planungsqualität; Executors und Verifier nutzen immer Sonnet.

## Projektdaten

Pro Projekt, bei Bedarf angelegt und in `.git/info/exclude` eingetragen, damit sie nie committet werden:

```
.claude/work/
├── ideas.md              # der Ideenpool: "- [ ] 2026-10-28 <Idee>"
└── <plan-id>/            # JJJJMMTT-HHMM-kurzer-slug
    ├── plan.md           # Aufgabenkarten + Zustand: die einzige Wahrheitsquelle
    └── log.md            # Protokoll von Start, Prüfung und Merge
```

Der Ideenpool gilt pro Projekt. Eine Idee, die du in Projekt A festhältst, ist in Projekt B nicht sichtbar.

## Gut zu wissen

- Triviale Änderungen (eine Datei, unter ca. 30 Zeilen) überspringen die Pipeline; Opus erledigt sie direkt.
- Opus fragt nur nach, wenn eine falsche Annahme teuer wäre (Datenverlust, Änderung einer öffentlichen API, nicht umkehrbare Migration), wenn ein Geheimnis oder eine kostenpflichtige Ressource nötig ist oder wenn die Anforderung grundlegend zur Architektur im Widerspruch steht.
- Ist das Verzeichnis kein Git-Repository, führt Concerto `git init` aus (nie in `$HOME` oder `/`) und legt einen Snapshot-Commit an.
- Nicht committete Änderungen werden vor einem Lauf automatisch gestasht und danach wiederhergestellt.
- Worktrees von Subagenten werden vom Standard-Branch aus angelegt; deshalb mergt jeder Executor zuerst `concerto/<plan-id>`, um frühere Ergebnisse zu übernehmen.
- Concerto nutzt Claude-Code-Funktionen (Skills, Subagenten mit `isolation: worktree`, Hooks), die sich schnell weiterentwickeln. Wenn nach einem Update etwas nicht mehr funktioniert, eröffne bitte ein Issue.

## Warum „Concerto“?

Ein Concerto ist ein Solist, der mit einem Orchester auftritt. Opus ist der Solist, die Sonnets sind das Orchester, und die Befehle sind die Partitur: ein Thema `hum`men, das ganze `opus` spielen, eine `encore`-Zugabe geben oder von vorn beginnen, *da capo*.

## Lizenz

MIT
