{ fetchFromGitHub }:
let
  rev = "0b9de252b3e8ad425199453648c11808a473c912";
in
{
  # Update this snapshot and the PC cargoDeps hash together.
  inherit rev;
  version = "21.0.0-dev12-unstable-2026-08-28";
  cargoHash = "sha256-61x5txV+5j7k1+/6kPaEncWDAcyfERRjFb5ZoLhtUG4=";
  src = fetchFromGitHub {
    owner = "alvr-org";
    repo = "ALVR";
    inherit rev;
    hash = "sha256-xmhDPH8bWwPZ5JN0GMfxTnSN1GHPV/YpG1DlW10es9I=";
  };

  # Pin the submodule independently, without fetching its Git history.
  openvrSrc = fetchFromGitHub {
    owner = "ValveSoftware";
    repo = "openvr";
    rev = "0924064316de3effbcd1acf1e309182a2deb1c05";
    hash = "sha256-xtCqro73fWQ6i0PiVmWYCK30DUSq1WeALoUolUjuWlE=";
  };
}
