# Keep these overlay policies distinct: hosts intentionally choose between
# llm-agents' shared nixpkgs overlay and the namespaced upstream packages.
{ inputs }:
let
  local-packages = import ../packages;
in
{
  inherit local-packages;

  llm-agents-overlay = _final: prev: {
    llm-agents = inputs.llm-agents.packages.${prev.stdenv.hostPlatform.system} or { };
  };

  # Limit devbox to this package; unrelated local overlays need not be evaluated.
  browseros-overlay = final: prev: {
    inherit (local-packages final prev) browseros-neo;
  };
}
