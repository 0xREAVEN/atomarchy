# Architecture

## Vue d'ensemble

```
ghcr.io/ublue-os/base-main:44           Fedora 44 Atomic + codecs + outils uBlue
 └─ atomarchy                           build_files/common/*.sh
     │   Omarchy 4 (RPM Omadora), Hyprland 0.57, Quickshell 0.3, SDDM, Plymouth,
     │   Docker, uupd, Bazaar, Homebrew, adaptation atomique d'Omarchy
     └─ atomarchy-gaming                build_files/gaming/*.sh
         noyau OGC + modules (images akmods de uBlue), pile jeu Terra, LACT,
         tuned-ppd, réglages de jeu

iso/Containerfile                       environnement d'installation Anaconda
 + image-builder generic-iso            → ISO avec l'image embarquée (hors ligne)
```

Un seul `Containerfile` multi-cibles (`--target atomarchy`, `--target atomarchy-gaming`). Chaque cible lance `build_files/build.sh <étape>`, qui exécute dans l'ordre les fichiers `build_files/<étape>/NN-*.sh`. Chaque fichier fait une seule chose, pour qu'un échec désigne directement un fichier.

## Étape `common` (image `atomarchy`)

| Fichier | Rôle |
|---|---|
| `00-repos.sh` | COPR `kammer/omadora`, `lionheartp/Hyprland`, `ublue-os/packages` et Terra (Terra est activé transaction par transaction) |
| `10-packages.sh` | `packages/common.txt`, avec `util-linux-script` épinglé sur la version de la base |
| `20-omarchy-atomic.sh` | Remplacement des commandes `omarchy-*` qui supposent un système modifiable (voir plus bas), noms Chromium, sessions |
| `30-login.sh` | SDDM (thème et greeter Hyprland d'Omarchy), cible graphique, thème Plymouth, arguments noyau du splash (`kargs.d`) |
| `40-system.sh` | Services (uupd, docker.socket, brew), politique de signature `policy.json` et `registries.d` |
| `45-identity.sh` | `image-info.json` (lu par ujust, uupd, `omarchy update`) et `os-release` (`ID=fedora` conservé) |
| `80-initramfs.sh` | Initramfs reconstruit avec le thème Plymouth |
| `99-cleanup.sh` | Dépôts dans leur état d'exécution, caches et `/var` nettoyés |

## Étape `gaming` (image `atomarchy-gaming`)

| Fichier | Rôle |
|---|---|
| `10-kernel.sh` | Noyau OGC et modules depuis `ghcr.io/ublue-os/akmods{,-extra}:ogc-44-<version>` (adapté de Bazzite), verrouillage de version, ntsync au démarrage |
| `20-packages.sh` | Mesa basculé entièrement sur `terra-mesa` (64 + 32 bits, vérifié), `packages/gaming.txt`, `tuned-ppd` à la place de `power-profiles-daemon` (+ client `powerprofilesctl`) |
| `30-tuning.sh` | `system_files/gaming` (sysctl, THP, PipeWire, variables Proton/Mesa, profil tuned), `lactd`, profil « performance » |
| `90/95/99` | Identité, initramfs et nettoyage (mêmes scripts que `common`) |

La version du noyau est figée (`ARG KERNEL_VERSION` dans le `Containerfile`), comme chez Bazzite : `akmods` et `akmods-extra` doivent correspondre exactement. Renovate propose une PR à chaque nouvelle version.

## Adaptation atomique d'Omarchy

Omadora écrit Omarchy pour une Fedora modifiable : dnf, Limine, Snapper. Sur bootc, `/usr` est en lecture seule. Les commandes concernées sont remplacées par les versions de `system_files/common/usr/share/atomarchy/bin/`, et les originaux sont conservés dans `/usr/share/atomarchy/orig/`.

| Commande Omarchy | Sur Atomarchy |
|---|---|
| `omarchy-pkg-add` / `-drop` / `-install` / `-remove` | `rpm-ostree install --apply-live` / `uninstall` (couches locales) |
| `omarchy-update-system-pkgs` | `rpm-ostree upgrade` (nouvelle image), marqueur de redémarrage pour `omarchy update` |
| `omarchy-update-aur-pkgs` | Flatpak système et utilisateur + Homebrew |
| `omarchy-update-available` | Digest du registre comparé au déploiement (via `skopeo`, sans droits root) |
| `omarchy-snapshot` | `create` → code 127 (« Snapper absent ») ; `restore` → `rpm-ostree rollback` |
| `omarchy-kernel`, `-refresh-limine`, `-hibernation-*`, `-plymouth-*`, `-channel-set`… | Message explicatif (ces fonctions relèvent de l'image ou de `ujust`) |

Le build échoue si une commande `omarchy-*` appelle encore `dnf` directement. Seul `omarchy-dev-pkg-test`, un outil de développement, est toléré.

## Session et dossier personnel

`/usr/share/wayland-sessions/omarchy.desktop` lance `/usr/libexec/atomarchy/session`, qui appelle `user-init` puis `uwsm start … hyprland.desktop`.

`user-init` copie les fichiers de `/etc/skel` qui **appartiennent aux paquets Omarchy** (`rpm -ql`), sans jamais écraser un fichier existant. Il branche ensuite le shell Omarchy dans `~/.bashrc.d` et lance `omarchy-provision-user`. Ce dernier est relancé à chaque connexion tant qu'il n'a pas abouti. `--reset` (`ujust atomarchy-reset-configs`) sauvegarde puis remplace les fichiers en conflit.

## CI

| Workflow | Déclencheur | Rôle |
|---|---|---|
| `lint.yml` | push, PR | ShellCheck, actionlint, hadolint, `just --fmt --check`, test de `pkgdiff.py` |
| `build.yml` | push, PR, quotidien | build → tests de fumée → démarrage VM → rapport de paquets ; sur `main`/`testing` : push `candidate-<sha>`, signature, vérification, promotion |
| `iso.yml` | mensuel, manuel, PR sur `iso/` | Vérification de la signature de l'image, environnement Anaconda, `image-builder generic-iso`, démarrage de l'ISO en VM, **installation complète automatisée puis démarrage du système installé** (`tests/iso-install-test.sh`), découpage et Release (jamais sur une PR) |
| `clean.yml` | hebdomadaire | Suppression des tags `candidate-*` de plus de 14 jours |

## Dépôts à l'exécution

Restent activés pour `omarchy pkg add` : Fedora, `kammer/omadora` et `lionheartp/Hyprland`. Terra et `ublue-os/packages` ne servent qu'au build et sont désactivés à la fin, comme sur Bazzite.

## Correctifs découverts par les tests

Chacun est couvert par un test de fumée ou par le test de démarrage.

| Problème | Correctif |
|---|---|
| Omarchy appelle `chromium` / `chromium.desktop`, alors que Fedora fournit `chromium-browser`. Les applis web et le navigateur par défaut ne fonctionnaient pas. | Lien `/usr/bin/chromium` et lanceur `chromium.desktop` ; celui de Fedora est masqué (`20-omarchy-atomic.sh`) |
| `base-main` n'a ni `xdg-user-dirs` ni `xdg-utils`, si bien que `omarchy-provision-user` échouait | Ajoutés à `packages/common.txt` |
| `mcelog` échoue à chaque démarrage sur les processeurs AMD (il ne gère que les Intel) | Drop-in `ExecCondition` : l'unité est ignorée hors Intel (`mcelog.service.d`) |
| Le `%posttrans` d'`omarchy-settings` exige `/run/lock`, absent d'un build en conteneur | Créé avant l'installation (`10-packages.sh`) |
| `dracut` échoue si `/root` (lien vers `/var/roothome`) n'a pas de cible | Cible créée avant la reconstruction de l'initramfs |
| `util-linux-script` faisait monter `util-linux` sous la base | Version épinglée sur celle de la base |
| `terra-mesa` n'a qu'une ancienne version de `mesa-va-drivers.i686` | VA-API 32 bits non installé (inutile pour les jeux) |
| Les dépendances faibles de `tuned` tiraient `kernel-tools` pour le noyau Fedora | `install_weak_deps=False` dans la variante jeu |
| L'installation depuis l'ISO échouait (`GetRawBlob: write /var/tmp/…: no space left on device`) : l'import décompresse chaque couche dans `/var/tmp`, qui est en RAM dans l'environnement live, et les plus grosses couches pèsent plusieurs Go | `/var/tmp` est monté sur le disque cible pendant le déploiement (`%pre-install`, puis nettoyé). Déploiement par `ostreecontainer` comme Bazzite, puis bascule vers l'image signée du registre (`iso/iso-setup.sh`). Couvert par le test d'installation de l'ISO |
| Après une installation par Anaconda, `systemd-remount-fs` échouait au premier démarrage (racine composefs en lecture seule, [ostreedev/ostree#3193](https://github.com/ostreedev/ostree/issues/3193)), et une installation en mode texte démarrait sans écran de connexion (`multi-user.target`) | `%post` : `ro` ajouté à `/` dans le `fstab` (comme le fait bootc, mais dès le premier démarrage) et `graphical.target` imposé. Le test d'installation vérifie aussi un second démarrage |
