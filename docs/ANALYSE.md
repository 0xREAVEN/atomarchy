# Analyse : Omarchy 4 sur Bazzite

> **Document historique.** Cette étude a mené au premier prototype, construit sur l'image Bazzite. Le projet est ensuite devenu **Atomarchy**, construit sur `ghcr.io/ublue-os/base-main` avec une variante jeu qui reprend le noyau et la pile jeu de Bazzite. L'architecture actuelle est décrite dans [ARCHITECTURE.md](ARCHITECTURE.md). Les constats sur Omarchy, Omadora et l'adaptation atomique restent valables.

Ce document a été rédigé le 1er novembre 2026. Il s'appuie sur le code source des projets suivants :

- Omarchy `v4.0.6` (stable) et la branche `master` (4.5 en développement), sur [basecamp/omarchy](https://github.com/basecamp/omarchy) ;
- [omarchy-pkgs](https://github.com/omacom-io/omarchy-pkgs), qui contient les PKGBUILD ;
- Bazzite `stable` (F44.20261026), sur [ublue-os/bazzite](https://github.com/ublue-os/bazzite) ;
- [Omadora](https://github.com/kamm3r/omadora) et [omadora-pkg](https://github.com/kamm3r/omadora-pkg) ;
- les dépôts COPR, Terra et Fedora 44, interrogés directement avec `dnf5`.

## 1. Verdict

**Oui, il est possible de récupérer la quasi-totalité d'Omarchy sur Bazzite.** Trois constats le rendent réaliste.

1. **Omarchy 4 est empaqueté, pas « scripté ».** Depuis la version 4 (« Quattro »), Omarchy est livré sous forme de deux paquets, `omarchy` et `omarchy-settings`. Ils s'installent dans `/usr/share/omarchy`, `/usr/bin/omarchy-*` et `/etc/skel`. C'est exactement le modèle d'une image immuable : tout ce qui est dans `/usr` est figé dans l'image, et `/etc/skel` initialise les comptes utilisateurs.
2. **Le portage Fedora existe déjà.** Omadora, de kamm3r, publie sur COPR les RPM `omarchy` et `omarchy-settings` pour Fedora 44, avec environ 140 paquets associés. Ils sont synchronisés avec Omarchy `master` au 29 octobre 2026.
3. **Le socle Fedora 44 est complet.** Hyprland 0.57, Quickshell, uwsm, le portail Hyprland, mise, starship, lazygit et toutes les applis maison d'Omarchy (aether, omasnap, omacut…) sont disponibles en RPM. Seul `omarchy-keyring` manque, et il ne sert qu'aux clés pacman, donc il est inutile ici.

Ce qui ne passe pas tel quel, c'est la couche « système mutable » d'Arch. Elle comprend pacman et l'AUR, Limine, Snapper, mkinitcpio, la session de connexion SDDM et les réglages noyau. Sur Bazzite, ces fonctions sont assurées par bootc/rpm-ostree, GRUB, les déploiements ostree et les réglages propres à Bazzite. Ce projet remplace donc environ 30 commandes `omarchy-*` par des équivalents atomiques.

## 2. Omarchy 4 en détail

### 2.1 Composants

| Domaine | Omarchy 4 | Remarque |
|---|---|---|
| Compositeur | Hyprland 0.57, **configuration en Lua** (`hyprland.lua`, `default/hypr/*.lua`) | Lua impose Hyprland ≥ 0.55. Omarchy applique ses propres correctifs (EGL NVIDIA, VRR, `wl_output`). |
| Bureau | **Quickshell** (`/usr/share/omarchy/shell`) : barre, lanceur/menu, notifications, OSD, écran de verrouillage, agent polkit, presse-papiers, dock, rappels | Waybar, Walker, Mako et hyprlock ont disparu dans la version 4. |
| Session | uwsm (`uwsm start … hyprland.desktop`) | `$OMARCHY_PATH` est injecté par `/usr/share/uwsm/env.d/10-omarchy`. |
| Thèmes | 22 thèmes en 4.0.6, 23 sur master. Chaque thème fournit des couleurs (`colors.toml`) et des modèles `default/themed/*.tpl` | Le thème courant est généré dans `~/.local/state/omarchy/current/`. |
| Commandes | 449 commandes `omarchy-*` en 4.0.6, 557 sur master, routées par `omarchy <groupe>` | Menus : `default/omarchy/omarchy-menu.jsonc` |
| Applis maison | aether, cliamp, hype, monologue, omacalc, omacut, omasnap, omawrite, owe, tobi-try, ttfx, signed, gliff, disktree | Toutes disponibles en RPM dans le COPR Omadora. |
| Applis tierces | Chromium (applis web `--app`), Nautilus, mpv, imv, Xournal++, Pinta, LibreOffice, Obsidian, LocalSend | |
| Outils dev | mise, Docker, lazygit, neovim (LazyVim), starship, zoxide, eza, fzf… | |
| Système | Limine + UKI, Snapper, mkinitcpio, SDDM avec greeter sous Hyprland, Plymouth, UFW, réglages sysctl/zram/I/O | Spécifique à Arch : c'est la partie qui doit être adaptée. |
| Mise à jour | `omarchy update` : verrou, snapshot, `pacman -Syu`, migrations par utilisateur, hooks, mise, AUR, vérification du boot, redémarrage | Garde-fou ALPM contre un `pacman -Syu` lancé directement. |

### 2.2 Les trois couches de configuration utilisateur

D'après `docs/file-layout.md` :

1. **Seed.** `/etc/skel` contient toute la configuration par défaut (`~/.config/hypr`, `alacritty`, `btop`…). `useradd -m` la copie à la création du compte.
2. **Finalize.** `omarchy-provision-user` (ex-`omarchy-finalize-user`) s'exécute une fois. Il crée les liens des « skills » d'agents IA et les dossiers XDG, définit le navigateur par défaut, génère le thème, et lance mise et le trousseau.
3. **Resync.** `omarchy-reinstall-configs` remet tout aux valeurs par défaut, de façon destructive.

S'y ajoutent les **migrations** (`/usr/share/omarchy/migrations/*.sh`), jouées par utilisateur au moment de la mise à jour.

**Conséquence pour Bazzite :** un compte créé *avant* le passage à l'image ne reçoit jamais `/etc/skel`. Ce projet ajoute donc une étape d'initialisation au premier lancement de la session Omarchy (voir §6).

### 2.3 Dépendance à Arch, mesurée

Sur les 449 commandes de la 4.0.6 :

- **342 ne référencent ni pacman, ni l'AUR, ni Limine, ni Snapper, ni mkinitcpio.** Elles sont portables telles quelles.
- **107 en référencent au moins un.** Le détail : `omarchy-pkg-add` (38 fichiers), pacman (35), Limine (9), mkinitcpio (7), Snapper (5), yay (5).

Omadora a déjà converti cette partie de pacman vers dnf5, ce qui laisse 26 commandes qui appellent `dnf`. Sur Bazzite, `dnf` ne peut pas modifier le système puisque `/usr` est en lecture seule. Ces commandes sont donc remplacées une seconde fois, par des équivalents atomiques.

## 3. Bazzite en détail (image `stable` du 26/10/2026)

| Élément | Valeur constatée dans l'image |
|---|---|
| Base | `ghcr.io/ublue-os/kinoite-main:44` (KDE) ou `silverblue-main:44` (GNOME), Fedora 44 |
| Noyau | `kernel-7.2.11-ogc4.1.fc44` (noyau « ogc » de Bazzite) |
| Déploiement | bootc 1.17 + rpm-ostree 2026.3, mises à jour par `uupd` (timer quotidien) et `ujust update` |
| Écran de connexion | **Plasma Login Manager** (`plasmalogin.service`) sur KDE, GDM sur GNOME. **SDDM n'est pas installé.** |
| Énergie | `tuned` + `tuned-ppd` (API D-Bus power-profiles), **sans le client `powerprofilesctl`** |
| Dépôts | Terra (désactivé après le build), negativo17 multimedia, COPR ublue-os/bazzite… avec des priorités et des exclusions sur Mesa et le noyau |
| Remplacements Terra | `terra-xorg-x11-server-Xwayland` (26.0.99), `terra-ddcutil`, `terra-wireplumber`, Mesa Terra |
| Applis | Flatpak système (Firefox, Okular, Flatseal…) via `bazzite-flatpak-manager`, Homebrew via `brew-setup` |
| Réglages | zram (`/etc/systemd/zram-generator.conf`), `sysctl.d/70-gaming.conf`, `60-block-scheduler.rules`, firewalld |
| Personnalisation | `ujust` importe `/usr/share/ublue-os/just/60-custom.just` s'il existe : c'est le point d'extension prévu pour les images dérivées. |
| Variantes | `bazzite` (KDE), `-nvidia`, `-nvidia-open`, `-gnome*`, `-deck*` (démarrent en mode jeu Steam) |

## 4. Projets existants

| Projet | Approche | Intérêt pour nous |
|---|---|---|
| **Omadora** ([kamm3r/omadora](https://github.com/kamm3r/omadora), COPR `kammer/omadora`) | Portage fidèle d'Omarchy 4 pour Fedora 44 **mutable** (dnf, Limine, dracut). Canaux stable, rc et edge. | **Base retenue.** Fournit les RPM `omarchy` et `omarchy-settings` et toutes les applis. Ne cible pas les systèmes atomiques. |
| COPR `whelanh/omarchy` | Applis Omarchy « Quattro » pour Fedora 44/45 | Doublon partiel d'Omadora. |
| [Omablue](https://github.com/odd-git/omablue) | Configuration *inspirée* d'Omarchy, sous **Sway**, pour secureblue | Approche atomique intéressante (Flatpak, brew, ujust), mais ce n'est pas Omarchy. |
| [Fedarchy](https://github.com/c3d/fedarchy) | Omarchy sur Fedora 42, l'AUR étant accessible via Distrobox | Ancien, avant la version 4. |
| Wayblue, hyprblue, bazzite-rice, Bluearchy… | Images uBlue avec Hyprland « générique » | Montrent que Hyprland sur Bazzite fonctionne, mais sans Omarchy. |

Le choix ici est donc de **réutiliser les RPM d'Omadora au moment du build de l'image**, plutôt que de réécrire Omarchy. On bénéficie ainsi du suivi d'upstream par Omadora, et on n'ajoute que la couche « atomique ».

## 5. Matrice de compatibilité

✅ identique · 🔁 adapté · ⛔ non applicable

| Fonction Omarchy | Statut | Sur Bazzite |
|---|---|---|
| Hyprland, configuration Lua, raccourcis, règles de fenêtres | ✅ | RPM Hyprland 0.57 (COPR lionheartp/Hyprland) |
| Bureau Quickshell (barre, menu, notifications, OSD, verrouillage, polkit) | ✅ | RPM quickshell 0.3.2 |
| Thèmes et changement de thème (`omarchy-theme-set`) | ✅ | Tout se passe dans `$HOME` |
| 23 thèmes, fonds d'écran, vidéos d'intro | ✅ | `omarchy-themes-intros` |
| Applis maison (aether, omasnap…) | ✅ | COPR Omadora |
| Chromium et applis web | ✅ | RPM Chromium de Fedora |
| Shell : alias, fonctions, starship, mise | 🔁 | Branché via `~/.bashrc.d/50-omarchy.sh`, sans réécrire le `.bashrc` existant |
| Méthode de saisie fcitx5 | 🔁 | Variables limitées à la session Omarchy (`/usr/share/uwsm/env.d`) pour ne pas perturber Plasma ou GNOME |
| Profils d'énergie | 🔁 | Client `powerprofilesctl` extrait du RPM et branché sur `tuned-ppd` de Bazzite |
| Installer un paquet (`omarchy pkg add`, menu Install) | 🔁 | `rpm-ostree install --apply-live` (couche locale, utilisable sans redémarrer) |
| Installer une appli (Flathub) | ✅ | Déjà en `flatpak --user` dans Omadora |
| `omarchy update` | 🔁 | Le pipeline Omarchy est conservé (migrations, hooks, mise…). L'étape paquets devient `rpm-ostree upgrade` (nouvelle image), puis Flatpak et Homebrew. |
| Indicateur de mise à jour (barre) | 🔁 | Compare le digest de l'image dans le registre avec le déploiement démarré (`skopeo`), sans droits root |
| Snapshots Snapper et retour arrière | 🔁 | Remplacés par les déploiements ostree (`rpm-ostree rollback`, menu GRUB) |
| Limine, UKI, choix du noyau | ⛔ | bootc/GRUB et noyau Bazzite. `omarchy kernel` affiche seulement la version. |
| mkinitcpio, hibernation automatique | ⛔ | À faire « à la Bazzite » (`rpm-ostree kargs`) |
| Thème SDDM et greeter Hyprland | ⛔ | Bazzite utilise Plasma Login Manager ou GDM. La session « Omarchy » y apparaît. |
| Thème Plymouth | 🔁 | Optionnel : `WITH_PLYMOUTH_THEME=1` au build, ou `ujust omarchy-plymouth` |
| Réglages zram, sysctl, ordonnanceur I/O d'Omarchy | ⛔ (volontaire) | On garde ceux de Bazzite, optimisés pour le jeu |
| UFW | ⛔ | firewalld, déjà présent dans Bazzite (comme chez Omadora) |
| Docker | 🔁 | `moby-engine`, `docker.socket` activé. Groupe docker via `ujust omarchy-docker-group`, car sur ostree les groupes sont dans `/usr/lib/group`. |
| Canaux stable, rc, edge | 🔁 | Correspondent à des tags d'image (`bootc switch …:tag`) |
| Réinitialisation d'usine | ⛔ | `rpm-ostree reset` et `ujust omarchy-reset-configs` |

## 6. Conflits Bazzite ↔ Omarchy et arbitrages

Ces conflits ont été **constatés en construisant l'image** sur `bazzite:stable` :

1. **Xwayland.** Tous les RPM Hyprland de Fedora (COPR lionheartp, sdegler, pm4rcin, Omadora-testing) exigent `xorg-x11-server-Xwayland(x86-64)`. Le Xwayland Terra de Bazzite ne fournit ce nom que sans suffixe d'architecture, si bien que dnf voulait réinstaller le Xwayland de Fedora, ce qui est impossible. **Correctif :** un paquet vide, `atomarchy-xwayland-compat`, est généré au build et déclare cette dépendance au nom du Xwayland de Bazzite, qui est conservé.
2. **ddcutil.** Bazzite fournit `terra-ddcutil`, qui entre en conflit avec le `ddcutil` de Fedora. Le paquet est donc retiré de la liste, puisque le binaire est déjà présent.
3. **util-linux.** `util-linux-script` aurait fait monter `util-linux` et ses bibliothèques sous Bazzite. Il est épinglé sur la version de Bazzite.
4. **Gestion d'énergie.** `power-profiles-daemon` (et la variante Omarchy) entre en conflit avec `tuned-ppd`. On garde tuned et on ajoute seulement le client `powerprofilesctl`.
5. **Écran de connexion.** Il n'y a pas de SDDM dans Bazzite. Les fichiers `sddm.conf.d` d'Omarchy sont retirés, et la session `omarchy.desktop` est remplacée par une version qui initialise le `$HOME` avant de lancer Hyprland. Les sessions « Hyprland » brutes sont masquées.
6. **Réglages système.** Les fichiers `zram-generator.conf.d/90-omarchy.conf`, `99-omarchy-sysctl.conf` (swappiness, dirty bytes), `60-omarchy-io-scheduler.rules` (kyber) et `omarchy-zswap.conf` sont retirés, car Bazzite a ses propres réglages pour le jeu.
7. **Plymouth.** Le `%post` d'`omarchy-settings` écrase `plymouthd.conf`. Le fichier de Bazzite est restauré, sauf si l'option du thème Omarchy est activée.
8. **`/etc/skel/.bashrc`.** Il est remplacé par celui d'Omarchy pour les *nouveaux* comptes. Les comptes existants reçoivent seulement un fichier `~/.bashrc.d`.
9. **Steam en démarrage automatique.** Bazzite place `steam.desktop` dans `~/.config/autostart`. uwsm respecte le démarrage automatique XDG, donc Steam démarre aussi dans la session Omarchy. C'est le comportement normal de Bazzite.
10. **Chromium.** Omarchy (et Omadora) utilisent la commande `chromium` et le lanceur `chromium.desktop` pour le navigateur par défaut, les associations MIME et **toutes les applis web**. Le RPM Fedora ne fournit que `/usr/bin/chromium-browser` et `chromium-browser.desktop`. Sans correctif, `omarchy-provision-user` échoue sur `xdg-settings set default-web-browser` et les applis web ne se lancent pas. **Correctif :** le build ajoute un lien `/usr/bin/chromium` et un `chromium.desktop`, et masque `chromium-browser.desktop` pour ne garder qu'une seule entrée. Reste une limite : `~/.config/chromium-flags.conf` d'Omarchy est propre au lanceur d'Arch et n'est pas lu par celui de Fedora.

## 7. Architecture de l'image

```
ghcr.io/ublue-os/bazzite:stable
  └─ build_files/build.sh
       1. active les COPR kammer/omadora et lionheartp/Hyprland (priorité 99, la plus basse)
       2. compatibilité Xwayland, épinglage util-linux
       3. dnf5 install packages.txt (+ fcitx5, + Docker) avec Terra pour cette transaction seulement
       4. powerprofilesctl → tuned-ppd
       5. copie system_files/ (session, user-init, ujust, service Flatpak)
       6. remplace ~30 omarchy-* par leurs versions atomiques (originaux gardés dans /usr/share/atomarchy/orig)
       7. arbitrages Bazzite (§6), image-info.json, nettoyage
  └─ bootc container lint
```

Au premier lancement de la session Omarchy, `/usr/libexec/atomarchy/session` effectue ces étapes :

1. Il copie les fichiers de `/etc/skel` qui **appartiennent aux paquets Omarchy** (`rpm -ql`), sans écraser ceux qui existent. La liste des fichiers conservés est écrite dans `~/.local/state/atomarchy/skipped-*.txt`.
2. Il branche l'environnement shell d'Omarchy dans `~/.bashrc.d`.
3. Il lance `omarchy-provision-user`.
4. Il démarre Hyprland via uwsm.

`ujust omarchy-reset-configs` applique ensuite les valeurs par défaut d'Omarchy partout, avec une sauvegarde préalable.

## 8. Risques et limites

- **Dépôts tiers.** Hyprland vient du COPR `lionheartp/Hyprland` et Omarchy du COPR `kammer/omadora`. COPR n'est pas audité par Fedora et la qualité peut varier. Le build quotidien protège un peu : une image qui ne se construit pas n'est pas publiée, et on peut toujours revenir au déploiement précédent.
- **Omadora suit `master`.** La version 4.0.0~alpha-0.75 correspond à upstream `84782475a` du 29/10/2026, c'est-à-dire *plus récente* que la 4.0.6 stable. Les correctifs arrivent vite, mais les régressions aussi.
- **Couches rpm-ostree.** Les paquets installés via le menu Install d'Omarchy deviennent des couches locales. Elles ralentissent un peu les mises à jour et peuvent bloquer une mise à niveau si un paquet disparaît. Pour les applis graphiques, il vaut mieux passer par Flathub.
- **Mises à jour automatiques.** `uupd.timer` de Bazzite reste actif et met l'image à jour en arrière-plan. `omarchy update` ne fait que déclencher la même chose de façon interactive, plus la partie Omarchy (migrations, mise…).
- **NVIDIA.** Utiliser la variante `bazzite-nvidia-open`. Le correctif EGL d'Omarchy pour NVIDIA n'est présent que dans le Hyprland « omadora-testing », pas dans celui de lionheartp.
- **Non testé graphiquement ici.** L'image a été construite et testée en conteneur : installation, commandes, initialisation d'un compte, `bootc container lint`. Le premier vrai démarrage sur une machine ou une VM reste à faire.
- **Applis Omarchy hors image.** Obsidian et LibreOffice sont installés en Flatpak (service `atomarchy-flatpaks`). Les applis commerciales du menu Install (1Password, Spotify…) passent par rpm-ostree ou Flathub selon le script.

## 9. Alternatives écartées

| Option | Pourquoi pas |
|---|---|
| `rpm-ostree install` d'Omarchy sur un Bazzite standard, sans image dérivée | Plus de 200 paquets en couche locale : mises à jour lentes et fragiles, pas reproductible, et les `omarchy-*` appelleraient toujours `dnf`. |
| Distrobox Arch avec Omarchy | Hyprland et Quickshell doivent tourner sur l'hôte (session, GPU, logind). Omarchy en conteneur ne fonctionne pas. |
| Silverblue « nu » + Omadora | Faisable avec ce même dépôt (`BASE_IMAGE=quay.io/fedora/fedora-silverblue:44`), mais on perd ce que Bazzite apporte au jeu : noyau, Mesa, Steam, gamescope, pilotes. |
| Fedora classique (mutable) + Omadora | C'est le cas d'usage officiel d'Omadora : le plus simple, mais sans la robustesse atomique ni les apports de Bazzite. |
| Réécrire Omarchy (façon Omablue) | Énorme travail, et on perdrait la compatibilité avec les mises à jour d'Omarchy. |

## 10. Validation effectuée

Le `build.sh` complet a été exécuté dans un conteneur `ghcr.io/ublue-os/bazzite:stable` (F44.20261026, KDE), suivi de 81 tests automatisés. Tous passent.

- **Paquets.** 206 paquets installés (+2 Go), **sans aucune mise à niveau ni remplacement de paquet Bazzite** (vérifié dans le résumé de transaction dnf).
- **Versions.** Omarchy `4.0.0~alpha-0.75.gite4c8bb74b6`, Hyprland `0.57.0-2`, Quickshell `0.3.2`, uwsm `0.27.1`.
- **Commandes atomiques.** Les 29 remplacements sont en place. Il ne reste aucun appel direct à `dnf install/remove/upgrade`, sauf dans `omarchy-dev-pkg-test`, réservé aux développeurs. La syntaxe bash de toutes les commandes `omarchy-*` est valide.
- **CLI et ujust.** CLI `omarchy`, liste des thèmes, `omarchy pkg present/missing/add`, `omarchy snapshot`, recettes `ujust omarchy-*` : OK.
- **Compte existant.** La configuration Hyprland est copiée et les fichiers de l'utilisateur sont conservés (puis sauvegardés et remplacés avec `--reset`). `omarchy-provision-user` va jusqu'au bout : marqueur `finalize-user` posé et navigateur par défaut `chromium.desktop`. L'environnement shell Omarchy se charge via `~/.bashrc.d`.
- **Lint.** `bootc container lint` : OK. Il reste 3 avertissements bénins : l'utilisateur `cups-browsed` déclaré dans `/etc/sysusers.d`, le cache dnf du test, et `authselect/checksum` venant de Bazzite.

Les tests ont révélé quatre problèmes, tous corrigés dans `build.sh` (voir §6) : la dépendance Xwayland, `ddcutil`, `util-linux`, et le nom de Chromium. Un cinquième ne concernait que les builds en conteneur : le `%posttrans` d'`omarchy-settings` exige `/run/lock`.

**Reste à faire :** un premier démarrage réel (machine ou VM) pour valider la session graphique.
