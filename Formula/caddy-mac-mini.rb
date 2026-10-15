# Formule Homebrew du Caddy du homelab — Mac Mini M4 (arm64).
#
# POURQUOI CE TAP EXISTE
# ----------------------
# homebrew-core livre un Caddy SANS plugins (« clean, no-plugins build », dixit
# la formule elle-meme), et les mainteneurs refusent les formules a plugins.
# Or Caddy n'a AUCUN chargement de module a l'execution : tout est lie
# statiquement au binaire. Sans ce tap, `crowdsec`, `rate_limit`, `layer4`,
# `dns.ovh`, `dns.cloudflare` et le WAF Coraza sont absents et le Caddyfile ne
# s'adapte pas.
#
# POURQUOI `caddy-mac-mini` ET NON `caddy`
# ----------------------------------------
# Une formule nommee `caddy` entrerait en collision avec celle de homebrew-core,
# et `brew install caddy` resout vers le CORE : on installerait le Caddy stock,
# sans plugins, et le Caddyfile echouerait a s'adapter. Le nom distinct rend
# cette confusion impossible.
#
# INSTALLATION
# ------------
#   brew tap JFAlexandre/caddy
#   brew install JFAlexandre/caddy/caddy-mac-mini
#   sudo brew services start caddy-mac-mini     # sudo => LaunchDaemon (boot)
#
# MISE A JOUR
# -----------
#   Les versions epinglees (url/tag, xcaddy, plugins) sont bump par Renovate :
#   voir la section "TOUT EST EPINGLE" ci-dessous et renovate.json a la racine
#   du depot. Apres merge d'une PR : `sudo brew update` puis
#   `brew upgrade caddy-mac-mini`.
#   NE PAS activer `brew autoupdate --upgrade` : un frontal qui route tout le
#   reseau ne doit pas changer de version tout seul sans validation.
#
# TOUT EST EPINGLE — ET C'EST RENOVATE QUI PROPOSE LES BUMPS
# ----------------------------------------------------------
# Trois choses sont epinglees, et il n'en faut pas moins :
#   1. Caddy lui-meme        -> `tag:` (voir la note REVISION ci-dessous)
#   2. xcaddy (l'outil)      -> `xcaddy@vX.Y.Z` dans install
#   3. chaque plugin         -> `module@vX.Y.Z` dans MODULES
#
# Sans epinglage, `xcaddy build` resout chaque plugin en `@latest` et
# `go run ...@latest` fait de meme pour xcaddy : deux builds du meme commit de
# formule peuvent produire des binaires DIFFERENTS. C'est inacceptable pour un
# frontal qui route tout le reseau — un module upstream casse, et le proxy
# frontal tombe au prochain rebuild.
#
# Renovate (renovate.json a la racine de ce depot) ouvre une PR par bump :
# les versions ci-dessous sont les SEULES a editer. Rien n'est pousse en
# `@latest` par Renovate.
#
# NOTE REVISION — POURQUOI IL N'Y A PAS DE `revision:`
# ----------------------------------------------------
# Le bloc url comportait un `revision: "<sha>"` (commit exact de la balise).
# Il a ete retire volontairement, pour deux raisons :
#   - `xcaddy build v#{version}` recupere la source depuis le proxy Go par
#     VERSION de module, jamais depuis le checkout Homebrew. La revision ne
#     servait donc a rien pour le binaire produit.
#   - Renovate ne sait bumper que la balise. Une revision figee survivrait au
#     bump : le frontal se declarerait en v2.12.0 tout en compilant le commit
#     de v2.11.6. Un build silencieusement faux est pire que pas de pin.
# Si un jour la revue veut un pin par commit, il faudra une CI qui recalcule
# la revision a chaque PR — voir la discussion dans renovate.json.
#
# `@v0.0.0-2026...` (transform-encoder) est une PSEUDO-VERSION Go : ce module
# n'a jamais tague de release. C'est normal, et Renovate sait les bumper.

class CaddyMacMini < Formula
  desc "Caddy du Mac Mini M4 : WAF Coraza, rate_limit, layer4, DNS OVH/Cloudflare"
  homepage "https://caddyserver.com/"
  url "https://github.com/caddyserver/caddy.git",
      tag: "v2.11.7"
  license "Apache-2.0"
  head "https://github.com/caddyserver/caddy.git", branch: "master"

  # Caddy est du Go pur : xcaddy et les plugins sont recuperes a la compilation.
  depends_on "go" => :build

  # --- Liste EXACTE des modules du frontal, CHAQUE version epinglee ---
  #
  #  caddy-ratelimit                 -> http.handlers.rate_limit
  #  caddy-l4                        -> layer4 (+ handlers/matchers)
  #  transform-encoder               -> caddy.logging.encoders.transform
  #  caddy-crowdsec-bouncer/{http,layer4,crowdsec}
  #                                  -> bouncer IP-ban HTTP + L4
  #                                     (3 paquets, UN seul module : les 3
  #                                      versions doivent rester identiques)
  #  caddy-dns/ovh                   -> dns.providers.ovh        (3wcreations.com)
  #  caddy-dns/cloudflare            -> dns.providers.cloudflare (jfalexandre.ovh)
  #  coraza-caddy/v2                 -> http.handlers.waf (WAF OWASP Coraza) ;
  #                                     le ruleset CRS est compile DANS le
  #                                     binaire (load_owasp_crs) : aucun
  #                                     fichier de regles a monter.
  MODULES = %w[
    github.com/mholt/caddy-ratelimit@v0.1.0
    github.com/mholt/caddy-l4@v0.1.2
    github.com/caddyserver/transform-encoder@v0.0.0-20260423033309-ba4124974830
    github.com/hslatman/caddy-crowdsec-bouncer/http@v0.14.1
    github.com/hslatman/caddy-crowdsec-bouncer/layer4@v0.14.1
    github.com/hslatman/caddy-crowdsec-bouncer/crowdsec@v0.14.1
    github.com/caddy-dns/ovh@v1.1.0
    github.com/caddy-dns/cloudflare@v0.2.4
    github.com/corazawaf/coraza-caddy/v2@v2.6.2
  ].freeze

  def install
    ENV["CGO_ENABLED"] = "0"

    with_args = MODULES.flat_map { |m| ["--with", m] }

    # xcaddy epingle : `@latest` rendrait le build non reproductible.
    system "go", "run", "github.com/caddyserver/xcaddy/cmd/xcaddy@v0.4.7",
           "build", "v#{version}",
           "--output", bin/"caddy",
           *with_args
  end

  def caveats
    <<~EOS
      Les routes vivent dans /Users/Shared/caddy (Caddyfile + routes/*.caddyfile),
      PAS dans le prefixe Homebrew.

      Demarrage :
        sudo brew services start caddy-mac-mini

      `sudo` est necessaire : sans lui, brew cree un LaunchAgent qui ne demarre
      qu'a l'OUVERTURE DE SESSION. Un serveur headless a besoin d'un
      LaunchDaemon, qui demarre au boot.

      Les versions de Caddy, xcaddy et des plugins sont epinglees ; Renovate
      propose les bumps par PR (voir renovate.json a la racine du tap).
    EOS
  end

  service do
    run [opt_bin/"caddy", "run",
         "--config",  "/Users/Shared/caddy/Caddyfile",
         "--adapter", "caddyfile",
         "--envfile", "/Users/Shared/caddy/private/caddy.env"]
    working_dir "/Users/Shared/caddy"

    # Les certs et cles privees ACME restent HORS de /Users/Shared/caddy :
    # ce dossier est accessible en ecriture au groupe admin, les cles non.
    environment_variables XDG_DATA_HOME:   (var/"lib").to_s,
                          XDG_CONFIG_HOME: (var/"config").to_s

    log_path       (var/"log/caddy.log").to_s
    error_log_path (var/"log/caddy.err.log").to_s
    keep_alive true
  end

  test do
    assert_match "v#{version}", shell_output("#{bin}/caddy version")

    # Les modules sont lies statiquement : on verifie qu'ils sont bien la.
    modules = shell_output("#{bin}/caddy list-modules")
    assert_match "dns.providers.ovh",        modules
    assert_match "dns.providers.cloudflare", modules
    assert_match "http.handlers.rate_limit", modules
    assert_match "http.handlers.waf",        modules
    assert_match "layer4",                   modules
    assert_match "http.handlers.crowdsec",   modules
  end
end
