# MDTHighlighter

> Addon **WoW: Midnight** — surligne les nameplates ennemis selon ta route MDT (Mythic Dungeon Tools).
> Fonctionne en **Mythic+, Mythic 0 (M0), Heroic, Normal** — ideal pour tester sans cle.

## Couleurs

| Couleur | Signification |
|---------|---------------|
| Orange  | **Pull actuel** — mobs a aggro maintenant (tank) |
| Jaune   | **Prochain pull** — preview du pull suivant |
| Bleu    | **Skipped** — mobs presents dans le donjon mais hors route |

## Prerequis

- **World of Warcraft: Midnight** (Interface `120001`)
- [MythicDungeonTools](https://www.curseforge.com/wow/addons/mythic-dungeon-tools) — avec une route chargee

## Installation

### Via CurseForge App
Recherche **MDTHighlighter** et installe.

### Manuelle
1. Telecharge le ZIP depuis [Releases](../../releases).
2. Extraire dans `World of Warcraft\_retail_\Interface\AddOns\`.
3. Activer l addon en jeu, MDT doit etre aussi actif.

## Commandes

```
/mdth                              - affiche le statut
/mdth on|off                       - activer / desactiver
/mdth current|next|skip on|off     - toggle par categorie
/mdth test                         - force un refresh (utile en M0 / apres import route)
/mdth color current|next|skip R G B  - couleur personnalisee (valeurs 0-1)
/mdth reset                        - reinitialiser les parametres
```

## Tester en M0

1. Lance un Mythic 0 (ou entre dans n importe quel donjon).
2. Ouvre MDT (`/mdt`) et importe ou cree une route.
3. Selectionne un pull dans la liste MDT.
4. Tape `/mdth test` pour forcer le rafraichissement si besoin.
5. Les nameplates s allument selon les couleurs.

## Architecture

- **MDTBridge.lua** — Polled toutes les secondes + hooks MDT. Calcule les 3 sets de NPC IDs (current, next, skip). Aucune restriction de difficulte.
- **NameplateManager.lua** — Ecoute `NAME_PLATE_UNIT_ADDED/REMOVED`. Extrait le NPC ID depuis le GUID. Applique `LibCustomGlow.PixelGlow_Start`.
- **Config.lua** — Slash commands `/mdth`. Couleurs persistees dans `SavedVariables`.

## Deploiement CurseForge

Creer un tag Git declenche le workflow automatiquement :

```bash
git tag v1.0.0 && git push --tags
```

Secrets/variables GitHub necessaires :

| Cle | Description |
|-----|-------------|
| `CF_API_KEY` (secret) | Token CurseForge |
| `CF_PROJECT_ID` (variable) | ID projet CurseForge |
| `WAGO_API_TOKEN` (secret) | Token Wago.io (optionnel) |
| `WAGO_PROJECT_ID` (variable) | ID projet Wago.io (optionnel) |

## Licence

MIT — voir [LICENSE](LICENSE).