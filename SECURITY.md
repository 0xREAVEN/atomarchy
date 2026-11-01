# Sécurité

## Signaler une vulnérabilité

Merci de **ne pas** ouvrir d'issue publique. Utilisez le signalement privé de GitHub : onglet *Security* → *Report a vulnerability*. Une réponse est donnée sous 7 jours.

Les problèmes qui viennent d'un projet amont sont à signaler à ce projet :

- Omarchy : [basecamp/omarchy](https://github.com/basecamp/omarchy) ;
- son portage Fedora : [kamm3r/omadora](https://github.com/kamm3r/omadora) ;
- Universal Blue et Bazzite : [ublue-os](https://github.com/ublue-os) ;
- Fedora : [Bugzilla](https://bugzilla.redhat.com).

## Versions suivies

Seuls les canaux publiés sont maintenus : `stable` (dernière image) et `testing`. Il n'y a pas de rétroportage : une correction arrive dans la prochaine image, construite chaque jour.

## Chaîne d'approvisionnement

- **Images signées.** Chaque image publiée est signée avec cosign (`keys/cosign.pub`). Les images contiennent une politique (`/etc/containers/policy.json`) qui refuse une image Atomarchy non signée par cette clé.
- **Tests avant publication.** Rien n'est publié avant que les tests dans le conteneur et le démarrage en VM aient réussi. La promotion vers un canal recopie le digest déjà signé et vérifié.
- **Sources des paquets.** Fedora, Universal Blue (`base-main`, `ublue-os/packages`, images `akmods` signées), Terra, et deux COPR tiers : `kammer/omadora` (Omarchy) et `lionheartp/Hyprland`. Les COPR ne sont pas audités par Fedora : leurs mises à jour arrivent dans l'image au build quotidien, et le canal `testing` sert à les essayer d'abord.
- **Versions figées.** Le noyau OGC et l'outil d'ISO sont figés et mis à jour par PR (Renovate), les actions GitHub par Dependabot.
- **Secure Boot.** Le noyau d'`atomarchy-gaming` est signé avec la clé de Universal Blue, à enrôler via MokManager, comme sur Bazzite. `atomarchy` utilise le noyau signé de Fedora.

## Clé de signature

La clé privée n'existe que dans le secret `SIGNING_SECRET` du dépôt. Si elle est compromise : générez une nouvelle paire, remplacez `keys/cosign.pub`, mettez à jour le secret, puis publiez une nouvelle image. Les machines installées reçoivent la nouvelle clé avec cette image, à condition qu'elles l'acceptent pendant la transition (`sudo bootc switch ghcr.io/0xreaven/atomarchy:stable`, puis de nouveau avec `--enforce-container-sigpolicy`).
