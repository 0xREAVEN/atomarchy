# Clé de signature

`cosign.pub` est la clé publique avec laquelle la CI signe les images. Elle est copiée dans les images (`/etc/pki/containers/atomarchy.pub`) avec une politique qui refuse toute image Atomarchy non signée par elle.

Mise en place (une seule fois, par le mainteneur) :

```bash
cosign generate-key-pair            # crée cosign.key (privée) et cosign.pub
mv cosign.pub keys/cosign.pub       # à committer
gh secret set SIGNING_SECRET < cosign.key
# si la clé a un mot de passe : gh secret set COSIGN_PASSWORD
```

Ne committez jamais `cosign.key`. Sans `keys/cosign.pub`, les images se construisent mais n'imposent pas de vérification de signature, et la CI refuse de publier sur `stable`.
