# Formule Homebrew du Caddy du homelab — Mac Mini M4 (arm64).
#
# POURQUOI CE TAP EXISTE
# ----------------------
# homebrew-core livre un Caddy SANS plugins (« clean, no-plugins build », dixit
# la formule elle-meme), et les mainteneurs refusent les formules a plugins.
# Or Caddy n'a AUCUN chargement de module a l'execution : tout est lie
# statiquement au binaire. Sans ce tap, `crowdsec`, `rate_limit`, `layer4`,
# `dns.ovh` et `dns.cloudflare` sont absents et le Caddyfile ne s'adapte pas.
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
#   Bumper url/revision ci-dessous, pousser, puis `brew upgrade caddy-mac-mini`.
#   NE PAS activer `brew autoupdate --upgrade` : un frontal qui route tout le
#   reseau ne doit pas changer de version tout seul sans validation.

class CaddyMacMini < Formula
  desc "Caddy du Mac Mini M4 : CrowdSec, rate_limit, layer4, DNS OVH/Cloudflare"
  homepage "https://caddyserver.com/"
  url "https://github.com/caddyserver/caddy.git",
      tag:      "v2.11.6",
      revision: "ac834b5dc70a17dca296f47c78c64587d6631cbb"
  license "Apache-2.0"
  head "https://github.com/caddyserver/caddy.git", branch: "master"

  # Caddy est du Go pur : xcaddy et les plugins sont recuperes a la compilation.
  depends_on "go" => :build

  # --- Liste EXACTE des modules du frontal (identique au Dockerfile valide) ---
  #
  #  caddy-ratelimit                 -> http.handlers.rate_limit
  #  caddy-l4                        -> layer4 (+ handlers/matchers)
  #  transform-encoder               -> caddy.logging.encoders.transform
  #  caddy-crowdsec-bouncer/{http,layer4,crowdsec}
  #                                  -> bouncer IP-ban HTTP + L4
  #  caddy-dns/ovh                   -> dns.providers.ovh     (3wcreations.com)
  #  caddy-dns/cloudflare            -> dns.providers.cloudflare (jfalexandre.ovh)
  #  coraza-caddy                    -> WAF OWASP Coraza, ruleset CRS compile
  #                                     DANS le binaire (load_owasp_crs) :
  #                                     aucun fichier de regles a monter.
  MODULES = %w[
    github.com/mholt/caddy-ratelimit
    github.com/mholt/caddy-l4
    github.com/caddyserver/transform-encoder
    github.com/hslatman/caddy-crowdsec-bouncer/http
    github.com/hslatman/caddy-crowdsec-bouncer/layer4
    github.com/hslatman/caddy-crowdsec-bouncer/crowdsec
    github.com/caddy-dns/ovh
    github.com/caddy-dns/cloudflare
    github.com/corazawaf/coraza-caddy/v2
  ].freeze

  def install
    ENV["CGO_ENABLED"] = "0"

    with_args = MODULES.flat_map { |m| ["--with", m] }

    system "go", "run", "github.com/caddyserver/xcaddy/cmd/xcaddy@latest",
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
    assert_match "layer4",                   modules
    assert_match "http.handlers.crowdsec",   modules
  end
end
