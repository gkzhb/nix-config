final: prev: {
  fmd = final.rustPlatform.buildRustPackage rec {
    pname = "fmd";
    version = "0.1.1";

    src = final.fetchCrate {
      inherit pname version;
      hash = "sha256-XzVVcPtELpn1B9GzVGeUm2CmeMSJrDSCt6QLQjxrf3s=";
    };

    cargoHash = "sha256-U72p3NAeYqfBhiSddADfu+zjTLd3ID6VUxJhT3tImDg=";

    meta = with final.lib; {
      description = "Find Markdown files by metadata";
      homepage = "https://github.com/zhouer/fmd";
      license = licenses.mit;
      platforms = platforms.all;
      mainProgram = "fmd";
    };
  };

  mmx-cli = final.stdenvNoCC.mkDerivation rec {
    pname = "mmx-cli";
    version = "1.0.15";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/mmx-cli/-/mmx-cli-${version}.tgz";
      sha256 = "sha256-kszuuvzDDYu/tZVDtNB0DNe+ZY/GYROi1n6rWFLILME=";
    };

    undiciSrc = final.fetchurl {
      url = "https://registry.npmjs.org/undici/-/undici-6.21.1.tgz";
      sha256 = "sha256-gNuW6OzIVLIwg+GnzosGnZZ0wYHcvoT9u3GouHEbTyQ=";
    };

    nativeBuildInputs = [ final.makeWrapper final.gnutar ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/mmx-cli $out/lib/node_modules/undici $out/bin
      tar -xzf $src --strip-components=1 -C $out/lib/node_modules/mmx-cli
      tar -xzf $undiciSrc --strip-components=1 -C $out/lib/node_modules/undici

      makeWrapper ${final.nodejs}/bin/node $out/bin/mmx \
        --set NODE_PATH $out/lib/node_modules \
        --add-flags $out/lib/node_modules/mmx-cli/dist/mmx.mjs

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "CLI for the MiniMax AI Platform";
      homepage = "https://github.com/MiniMax-AI/cli";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
      platforms = platforms.all;
      mainProgram = "mmx";
    };
  };
}
