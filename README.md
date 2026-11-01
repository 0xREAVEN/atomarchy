# Omarchy sur Bazzite

Une image [bootc](https://bootc-dev.github.io/bootc/) qui ajoute **[Omarchy 4](https://omarchy.org)** à **[Bazzite](https://bazzite.gg)**. On y retrouve Hyprland 0.57 en configuration Lua, le bureau Quickshell, les 23 thèmes, plus de 500 commandes `omarchy-*` et les applis Omarchy. Bazzite conserve tout ce qu'il apporte pour le jeu : noyau, Mesa, Steam, gamescope, pilotes et mises à jour atomiques.

- Au démarrage, une session **« Omarchy »** apparaît sur l'écran de connexion, à côté de Plasma (ou de GNOME).
- Omarchy provient des RPM Fedora du projet [Omadora](https://github.com/kamm3r/omadora) (COPR `kammer/omadora`). Hyprland et Quickshell proviennent du COPR `lionheartp/Hyprland`.
- Les commandes Omarchy qui supposent un système modifiable (pacman/dnf, Limine, Snapper) sont remplacées par des équivalents atomiques : rpm-ostree, bootc, Flatpak et Homebrew.

L'analyse complète est dans **[docs/ANALYSE.md](docs/ANALYSE.md)** : ce qui est repris, adapté ou abandonné, les conflits avec Bazzite et les risques.

## Images

| Image | Base | Pour |
|---|---|---|
| `ghcr.io/<toi>/bazzite-omarchy:stable` | `bazzite` (KDE) | GPU AMD ou Intel |
| `ghcr.io/<toi>/bazzite-omarchy-nvidia:stable` | `bazzite-nvidia-open` | NVIDIA RTX 20xx et plus récent |

Pour une variante GNOME, décommente l'entrée correspondante dans `.github/workflows/build.yml`. Les images `-deck` ne sont pas prises en charge, car elles démarrent en mode jeu Steam.

## Installation

Il faut d'abord un Bazzite installé (ISO officielle sur [bazzite.gg](https://bazzite.gg)), puis :

1. Dans ce dépôt GitHub, va dans **Actions** et lance **build-image** (ou attends le build quotidien). L'image est publiée sur `ghcr.io/<toi>/…`. Rends le paquet public dans *Packages → Package settings*, ou connecte-toi au registre sur la machine.
2. Sur la machine Bazzite, bascule vers l'image :

   ```bash
   sudo bootc switch ghcr.io/0xreaven/bazzite-omarchy:stable
   ```

   Variante équivalente avec rpm-ostree :

   ```bash
   sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/0xreaven/bazzite-omarchy:stable
   ```

3. Redémarre. Sur l'écran de connexion, choisis la session **Omarchy**.

À la première ouverture de la session, ton dossier personnel est préparé automatiquement :

- les configurations Omarchy sont copiées **sans écraser tes fichiers existants** (la liste des fichiers conservés est dans `~/.local/state/omarchy-atomic/`) ;
- l'environnement shell d'Omarchy est branché dans `~/.bashrc.d/` ;
- `omarchy-provision-user` est lancé.

Pour appliquer partout les réglages Omarchy par défaut (avec une sauvegarde préalable) :

```bash
ujust omarchy-reset-configs
```

### Revenir en arrière

Pour redémarrer sur le déploiement précédent (également proposé dans le menu de démarrage) :

```bash
sudo rpm-ostree rollback
```

Pour revenir à Bazzite standard :

```bash
sudo bootc switch ghcr.io/ublue-os/bazzite:stable
```

## Au quotidien

| Besoin | Commande |
|---|---|
| Tout mettre à jour (image, Flatpak, brew, migrations Omarchy) | `omarchy update` ou `ujust update` |
| Installer une appli graphique | Menu Omarchy → Install (Flathub) ou Bazaar |
| Installer un paquet système | `omarchy pkg add <paquet>`, qui l'ajoute comme couche rpm-ostree utilisable tout de suite |
| Outils de dev isolés | `distrobox`, `toolbox` ou `brew` |
| Versions installées | `ujust omarchy-info` |
| Docker sans sudo | `ujust omarchy-docker-group` (attention : le groupe docker équivaut à un accès root) |
| Thème de démarrage Omarchy | `ujust omarchy-plymouth` |

## Construire localement

```bash
podman build -t localhost/bazzite-omarchy:dev .
```

Puis pour basculer sur cette image locale :

```bash
sudo bootc switch --transport containers-storage localhost/bazzite-omarchy:dev
```

Pour tester l'image construite :

```bash
podman run --rm -v ./tests:/tests:ro localhost/bazzite-omarchy:dev bash /tests/smoke.sh
```

Options de build (`--build-arg`) :

| Argument | Défaut | Effet |
|---|---|---|
| `BASE_IMAGE` | `ghcr.io/ublue-os/bazzite` | ou `…/bazzite-nvidia-open`, `…/bazzite-gnome` |
| `WITH_DOCKER` | `1` | moby-engine, compose, buildx |
| `WITH_FCITX` | `1` | fcitx5 et les méthodes de saisie CJK d'Omarchy |
| `WITH_PLYMOUTH_THEME` | `0` | thème de démarrage Omarchy (initramfs reconstruit dans l'image) |

## Contenu du dépôt

```
Containerfile                 base Bazzite → build.sh → bootc container lint
build_files/build.sh          dépôts, paquets, correctifs de compatibilité, arbitrages Bazzite
build_files/packages.txt      liste Omarchy → noms Fedora (d'après Omadora)
system_files/
  usr/share/wayland-sessions/omarchy.desktop    session « Omarchy »
  usr/libexec/omarchy-atomic/session, user-init  préparation du $HOME puis uwsm/Hyprland
  usr/share/omarchy-atomic/bin/omarchy-*        commandes remplacées (pkg, update, snapshot…)
  usr/share/ublue-os/just/60-custom.just        recettes ujust omarchy-*
  usr/lib/systemd/system/omarchy-atomic-flatpaks.service  Obsidian, LibreOffice (Flathub)
.github/workflows/build.yml   build quotidien, tests puis publication sur GHCR (signature cosign optionnelle)
tests/smoke.sh                81 tests lancés dans l'image (commandes, initialisation du $HOME, arbitrages)
docs/ANALYSE.md               l'analyse complète
```

## Signer l'image (optionnel)

1. Génère une paire de clés avec `cosign generate-key-pair`.
2. Ajoute la clé privée comme secret de dépôt `SIGNING_SECRET`.
3. Le workflow signera chaque image poussée.

Pour imposer la vérification côté machine, il faut en plus livrer `cosign.pub` et une politique dans `/etc/containers/policy.json`, comme le fait le [modèle d'image uBlue](https://github.com/ublue-os/image-template).

## Crédits

- [Omarchy](https://github.com/basecamp/omarchy) par DHH et Basecamp (MIT)
- [Omadora](https://github.com/kamm3r/omadora) par kamm3r, le portage Fedora d'Omarchy dont on utilise les RPM
- [Bazzite](https://github.com/ublue-os/bazzite) et [Universal Blue](https://universal-blue.org)
- [lionheartp/Hyprland](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/) pour Hyprland et Quickshell sur Fedora
