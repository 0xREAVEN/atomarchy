# Contribuer à Atomarchy

## Principes

- **Une étape, un fichier.** Le build exécute `build_files/<common|gaming>/NN-*.sh` dans l'ordre. Ajoutez une étape plutôt que d'alourdir une étape existante.
- **Échouer bruyamment.** Une hypothèse sur l'amont (un fichier d'Omadora, un paquet, un chemin) se vérifie avec `die "…"`, pour que le build échoue au lieu de produire une image incomplète.
- **Ne pas forker Omarchy.** Les différences avec Omadora se limitent aux commandes de `system_files/common/usr/share/atomarchy/bin/` et aux petites retouches de `20-omarchy-atomic.sh`. Une correction utile à tous les utilisateurs de Fedora doit d'abord être proposée à [Omadora](https://github.com/kamm3r/omadora).
- **Les fichiers utilisateur sont sacrés.** Rien n'écrase un fichier de `$HOME` sans sauvegarde.

## Avant une PR

```bash
just lint
just build && just test
just build atomarchy-gaming && just test atomarchy-gaming
just boot-test                     # si vous avez KVM
```

La CI fait la même chose sur chaque PR, plus le démarrage en VM : regardez la capture `boot-*/screen.png` dans les artefacts si vous avez touché à la session ou à l'écran de connexion.

## Ajouter un paquet

- Dans les deux images : `build_files/packages/common.txt`.
- Dans la variante jeu seulement : `build_files/packages/gaming.txt`.

Indiquez en commentaire pourquoi le paquet est là, surtout s'il vient d'un dépôt tiers.

## Branches et publication

- `main` → canal `stable` (et build quotidien).
- `testing` → canal `testing`.
- Toute autre branche ou PR : build et tests, sans publication.

Commits : un changement cohérent par commit, message à l'impératif (`gaming: add hid-xpadneo`).
