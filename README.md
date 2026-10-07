# homebrew-caddy-homelab

Tap Homebrew pour le Caddy du homelab — Mac Mini M4 (`arm64`).

## Pourquoi ce tap existe

`homebrew-core` livre un Caddy **sans plugins**. La formule amont le dit
elle-même :

> « The current version of the formulae installs a **clean, no-plugins build**. »

Et les mainteneurs refusent les formules à plugins :

> « we don't support formula with plugins […] this wouldn't be allowed in
> homebrew/core. But you can always consider hosting it in a **personal tap**. »

Or Caddy n'a **aucun chargement de module à l'exécution** : tout est lié
statiquement au binaire. Sans ce tap, `crowdsec`, `rate_limit`, `layer4`,
`dns.ovh` et `dns.cloudflare` sont absents, et le Caddyfile ne s'adapte même pas.

## Installation

```sh
brew tap JFAlexandre/caddy-homelab
brew install JFAlexandre/caddy-homelab/caddy-homelab

# sudo est INDISPENSABLE : sans lui, brew crée un LaunchAgent, qui ne démarre
# qu'à l'ouverture de session. Un serveur headless veut un LaunchDaemon.
sudo brew services start caddy-homelab
```

## Modules compilés

| Module | Apporte |
|---|---|
| `mholt/caddy-ratelimit` | `http.handlers.rate_limit` |
| `mholt/caddy-l4` | `layer4` (+ handlers et matchers) |
| `caddyserver/transform-encoder` | `caddy.logging.encoders.transform` |
| `hslatman/caddy-crowdsec-bouncer/http` | bouncer IP-ban HTTP |
| `hslatman/caddy-crowdsec-bouncer/layer4` | bouncer IP-ban L4 |
| `hslatman/caddy-crowdsec-bouncer/crowdsec` | app CrowdSec |
| `caddy-dns/ovh` | `dns.providers.ovh` (zone `3wcreations.com`) |
| `caddy-dns/cloudflare` | `dns.providers.cloudflare` (zone `jfalexandre.ovh`) |

## Ce que ce repo ne contient PAS

**Aucune route, aucun Caddyfile.** Ce tap ne contient que la *recette de
compilation* du binaire. La configuration vit dans `/Users/Shared/caddy`
(`Caddyfile` + `routes/*.caddyfile`), dans un **autre** dépôt.

C'est volontaire : ça permet de changer une route sans jamais recompiler.

## Mise à jour

1. Bumper `url`/`revision` dans `Formula/caddy-homelab.rb` (récupérer le commit
   avec : `curl -s https://api.github.com/repos/caddyserver/caddy/git/tags/<tag>`)
2. Pousser
3. Sur le Mac : `brew upgrade caddy-homelab`

⚠ **Ne pas activer `brew autoupdate --upgrade`.** Un frontal qui route tout le
réseau ne doit pas changer de version seul : une mise à jour silencieuse du
composant qui porte tous les certificats et toutes les routes, c'est une panne
qui arrive la nuit sans que personne n'ait rien touché.

## Vérifier que le build est correct

```sh
caddy list-modules | grep -E 'rate_limit|layer4|dns.providers|crowdsec'
```

`brew test caddy-homelab` fait ce contrôle automatiquement.
