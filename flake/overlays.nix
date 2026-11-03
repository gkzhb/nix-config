# Keep these overlay policies distinct: hosts intentionally choose between
# llm-agents' shared nixpkgs overlay and the namespaced upstream packages.
{ inputs }:
let
  local-packages = import ../packages;
in
{
  inherit local-packages;

  # Keep fast-moving tools isolated from the host package set and its overlays.
  # Reuse the host license policy, not a blanket allowUnfree exception.
  edge-overlay = _final: prev: {
    edge = import inputs.nixpkgs-edge {
      system = prev.stdenv.hostPlatform.system;
      inherit (prev) config;
    };
  };

  llm-agents-overlay = _final: prev: {
    llm-agents = inputs.llm-agents.packages.${prev.stdenv.hostPlatform.system} or { };
  };

  # Limit devbox to this package; unrelated local overlays need not be evaluated.
  browseros-overlay = final: prev: {
    inherit (local-packages final prev) browseros-neo;
  };
}
