<div align="center">

# Atomarchy

**[Omarchy 4](https://omarchy.org) sur Fedora Atomic : le bureau Hyprland + Quickshell de DHH, en image système immuable.**

[![build](https://github.com/0xREAVEN/atomarchy/actions/workflows/build.yml/badge.svg)](https://github.com/0xREAVEN/atomarchy/actions/workflows/build.yml)
[![lint](https://github.com/0xREAVEN/atomarchy/actions/workflows/lint.yml/badge.svg)](https://github.com/0xREAVEN/atomarchy/actions/workflows/lint.yml)
[![iso](https://github.com/0xREAVEN/atomarchy/actions/workflows/iso.yml/badge.svg)](https://github.com/0xREAVEN/atomarchy/actions/workflows/iso.yml)
![Fedora](https://img.shields.io/badge/Fedora-44-blue?logo=fedora)
![Licence](https://img.shields.io/badge/Licence-Apache%202.0-blue.svg)

</div>

Atomarchy est une distribution dérivée de [Universal Blue](https://universal-blue.org) : chaque image est un conteneur [bootc](https://bootc-dev.github.io/bootc/) construit chaque jour, testé dans une machine virtuelle, signé, puis publié. Le système se met à jour d'un bloc et revient en arrière d'une commande.

![Écran de connexion d'Atomarchy (SDDM, thème Omarchy), capturé par le test de démarrage de la CI](docs/images/login.png)

> Projet communautaire, **non affilié** à Omarchy, Basecamp ou Universal Blue. Omarchy provient des RPM Fedora du projet [Omadora](https://github.com/kamm3r/omadora).

## Les deux images

| Image | Pour qui | Contenu |
|---|---|---|
| **`atomarchy`** | Tout le monde | `base-main` de Universal Blue (Fedora 44 Atomic, codecs) + Omarchy 4 : Hyprland 0.57 (config Lua), bureau Quickshell, 23 thèmes, plus de 500 commandes `omarchy`, applis Omarchy, SDDM et Plymouth aux couleurs d'Omarchy, Docker, Bazaar, Homebrew, mises à jour automatiques |
| **`atomarchy-gaming`** | PC de jeu (AMD/Intel) | Tout `atomarchy` + **noyau de jeu de Bazzite (OGC)**, ntsync, pilotes de volants (Fanatec, Thrustmaster, Logitech), manettes Xbox (xone), `ryzen_smu`, `zenergy` ; Mesa de Terra en 32 et 64 bits, Steam, Gamescope, MangoHud, umu-launcher, vkBasalt ; LACT ; tuned + tuned-ppd et les réglages de jeu de Bazzora |

Cartes NVIDIA : pas encore prises en charge.

## Installation

### Depuis l'ISO

Les ISO sont publiées chaque mois dans les [Releases](https://github.com/0xREAVEN/atomarchy/releases). Elles sont découpées en parties de 1,9 Go à cause de la limite de GitHub. Les instructions de reconstitution et de vérification sont dans chaque Release. L'image est embarquée dans l'ISO, l'installation se fait donc sans réseau.

**Atomarchy Gaming avec Secure Boot :** au premier redémarrage, *MokManager* propose *Enroll MOK*. Validez avec le mot de passe `universalblue` (la clé de Universal Blue qui signe le noyau de jeu, comme sur Bazzite).

### Depuis un Fedora Atomic ou un Universal Blue existant (Bazzite, Bluefin, Aurora…)

1. Basculez sur l'image (non vérifiée la première fois, la clé n'étant pas encore sur la machine) :

   ```bash
   sudo bootc switch ghcr.io/0xreaven/atomarchy:stable
   ```

2. Redémarrez.
3. Vérifiez les signatures pour toutes les mises à jour suivantes :

   ```bash
   sudo bootc switch --enforce-container-sigpolicy ghcr.io/0xreaven/atomarchy:stable
   ```

Pour la variante jeu, remplacez `atomarchy` par `atomarchy-gaming`.

À la première ouverture de la session **Omarchy**, votre dossier personnel est préparé : les configurations d'Omarchy sont copiées **sans écraser vos fichiers** (la liste de ceux conservés est indiquée), puis la configuration utilisateur d'Omarchy est lancée.

## Canaux

| Canal | Tag | Contenu |
|---|---|---|
| **stable** | `:stable`, `:latest`, `:44` | La branche `main`, construite chaque jour |
| **testing** | `:testing` | La branche `testing`, pour essayer les changements avant tout le monde |

```bash
ujust atomarchy-channel testing
```

Chaque publication a aussi un tag daté (`stable-44.20261101`), ce qui permet de revenir à une version précise.

## Au quotidien

| Besoin | Commande |
|---|---|
| Tout mettre à jour (image, Flatpak, Homebrew, migrations Omarchy) | `omarchy update` (sinon `uupd` le fait en arrière-plan) |
| Revenir à la version précédente | `sudo rpm-ostree rollback`, ou le menu de démarrage |
| Installer une application | Bazaar (Flathub), ou le menu Omarchy → Install |
| Ajouter un paquet système | `omarchy pkg add <paquet>` (couche rpm-ostree, utilisable tout de suite) |
| Diagnostic | `ujust atomarchy-doctor` |
| Remettre les configurations Omarchy (avec sauvegarde) | `ujust atomarchy-reset-configs` |
| Docker sans `sudo` | `ujust atomarchy-docker-group` (le groupe docker équivaut à un accès root) |
| Overclocking / undervolt AMD (gaming) | `ujust toggle-amdgpu-overdrive`, puis LACT |
| HDR + Wayland natif pour Proton (gaming) | `ujust toggle-proton-hdr` |

## Qualité et sécurité

Chaque build, sur chaque image, passe par ces étapes :

1. **Lint** : ShellCheck, actionlint, hadolint, formatage `just`.
2. **Construction** de l'image, puis `bootc container lint`.
3. **Tests de fumée dans l'image** (une centaine de vérifications) : commandes Omarchy, adaptation atomique, SDDM et Plymouth, services, politique de signature, noyau OGC et modules, Mesa de Terra uniquement, préparation d'un compte existant.
4. **Démarrage réel** : installation sur un disque virtuel avec `bootc install`, démarrage dans QEMU/KVM, vérifications par SSH (aucune unité en échec, SDDM lancé, noyau, ntsync…), capture de l'écran de connexion.
5. **Rapport des paquets** ajoutés, retirés et mis à jour par rapport à la version publiée.
6. **Publication en `candidate`, signature cosign, vérification**, puis **promotion** vers le canal sous le même digest.

Une image qui échoue à une étape n'est jamais publiée : les utilisateurs restent sur la dernière version validée. Les versions des actions, du noyau OGC et de l'outil d'ISO sont tenues à jour par Dependabot et Renovate. Voir [SECURITY.md](SECURITY.md).

Pour vérifier une image :

```bash
cosign verify --key keys/cosign.pub ghcr.io/0xreaven/atomarchy:stable
```

## Construire soi-même

```bash
just build                     # ou: just build atomarchy-gaming
just test                      # tests de fumée
just boot-test                 # démarrage en VM (KVM)
just lint
```

L'architecture est décrite dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) et l'étude initiale (Omarchy, Bazzite, choix de conception) dans [docs/ANALYSE.md](docs/ANALYSE.md). Pour contribuer : [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence et remerciements

Licence **Apache 2.0** ([LICENSE](LICENSE), [NOTICE](NOTICE)).

Tout repose sur le travail de [Omarchy](https://github.com/basecamp/omarchy) (DHH, MIT), [Omadora](https://github.com/kamm3r/omadora) (kamm3r, MIT), [Universal Blue](https://universal-blue.org) et [Bazzite](https://bazzite.gg) (Apache 2.0), [Terra](https://terra.fyralabs.com), le COPR [lionheartp/Hyprland](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/), [Fedora](https://fedoraproject.org) et [osbuild](https://osbuild.org).
