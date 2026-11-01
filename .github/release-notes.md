### Installer

1. Téléchargez toutes les parties `.iso.partNN` de l'image voulue et son fichier `-CHECKSUM`.
2. Reconstituez et vérifiez l'ISO :
   - Linux / macOS : `cat atomarchy-*.iso.part* > atomarchy.iso && sha256sum -c --ignore-missing atomarchy-*-CHECKSUM`
   - Windows : `cmd /c copy /b atomarchy-*.iso.part* atomarchy.iso`, puis comparez `Get-FileHash atomarchy.iso` au fichier `-CHECKSUM`.
3. Copiez l'ISO sur une clé avec [Ventoy](https://www.ventoy.net/) ou [Fedora Media Writer](https://fedoraproject.org/workstation/download), démarrez dessus et suivez l'installateur.

L'image est embarquée dans l'ISO (installation hors ligne) ; le système installé se met ensuite à jour tout seul sur son canal.

**Atomarchy Gaming et Secure Boot** : le noyau de jeu est signé avec la clé Universal Blue. Au premier redémarrage, l'écran bleu *MokManager* propose *Enroll MOK* : validez avec le mot de passe `universalblue`.

### Vérifier l'image installée

```bash
cosign verify --key https://raw.githubusercontent.com/0xREAVEN/atomarchy/main/keys/cosign.pub ghcr.io/0xreaven/atomarchy:stable
```
