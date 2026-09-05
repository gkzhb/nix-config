{
  lib,
  alvr,
  fetchFromGitHub,
  rustPlatform,
  ffmpeg_8,
  vulkan-headers,
  vulkan-loader,
  makeWrapper,
  android-tools,
}:
let
  snapshot = import ./alvr-source.nix { inherit fetchFromGitHub; };
  inherit (snapshot) rev src openvrSrc;

  # Master uses FFmpeg 8.1, not the patched FFmpeg 6 used by ALVR 20.14.1.
  ffmpeg-alvr =
    (ffmpeg_8.override {
      withHardcodedTables = false;
      withHtmlDoc = false;
      withManPages = false;
      withPodDoc = false;
      withTxtDoc = false;
      withDocumentation = false;
    }).overrideAttrs
      (old: {
        patches =
          (old.patches or [ ])
          ++ map (name: "${src}/alvr/xtask/patches/${name}") [
            "0001-lavu-hwcontext_vulkan-Fix-importing-RGBx-frames-to-C.patch"
            "0002-vaapi_encode-Force-enable-global-header.patch"
            "0003-vaapi_encode_h265-Set-vui_parameters_present_flag.patch"
            "0004-vaapi_encode-Allow-to-dynamically-change-bitrate-and.patch"
            "0005-vaapi_encode-Add-filler_data-option.patch"
            "0006-Add-AV_VAAPI_DRIVER_QUIRK_HEVC_ENCODER_ALIGN_64_16-f.patch"
          ];
        doCheck = false;
      });
in
(alvr.override { inherit ffmpeg-alvr; }).overrideAttrs (old: {
  inherit (snapshot) version;
  inherit src;
  # Recreate cargoDeps explicitly: overriding cargoHash alone leaves nixpkgs'
  # buildRustPackage dependency fetcher using the release's original hash.
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = snapshot.cargoHash;
  };

  # The 20.x build-script patches no longer apply. Supply Nix dependencies in
  # the layout expected by upstream instead; never run `cargo xtask prepare-deps`.
  patches = [ ];
  postPatch = ''
    cp -r ${openvrSrc}/. openvr/
    chmod -R u+w openvr
    mkdir -p deps/linux/ffmpeg
    ln -s ${lib.getDev ffmpeg-alvr} deps/linux/ffmpeg/alvr_build
    ln -s ${vulkan-headers} deps/linux/vulkan-headers
    # Nix supplies shared FFmpeg libraries, unlike upstream's static SDK.
    substituteInPlace alvr/server_openvr/build.rs \
      --replace-fail 'let pkg = pkg_config::Config::new().statik(true).to_owned();' \
                     'let pkg = pkg_config::Config::new().to_owned();'
  '';

  nativeBuildInputs = old.nativeBuildInputs ++ [ makeWrapper ];
  # Build the Linux streamer, not the Android client or standalone launcher.
  cargoBuildFlags = [
    "-p"
    "alvr_dashboard"
    "-p"
    "alvr_server_openvr"
    "-p"
    "alvr_vrcompositor_wrapper"
    "-p"
    "alvr_vulkan_layer"
  ];
  cargoTestFlags = [
    "-p"
    "alvr_dashboard"
    "-p"
    "alvr_server_openvr"
    "-p"
    "alvr_vrcompositor_wrapper"
    "-p"
    "alvr_vulkan_layer"
  ];
  # wgpu loads libvulkan.so.1 with dlopen, so buildInputs/ldd alone do not
  # ensure the dashboard can find the Vulkan loader at runtime.
  postFixup = (old.postFixup or "") + ''
    wrapProgram $out/bin/alvr_dashboard \
      --prefix PATH : ${lib.makeBinPath [ android-tools ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ vulkan-loader ]}
  '';

  passthru = (old.passthru or { }) // {
    inherit rev openvrSrc ffmpeg-alvr;
    # nixpkgs' release updater must not turn this master snapshot into a release.
    updateScript = null;
  };
  meta = old.meta // {
    description = "ALVR master snapshot with SteamVR 2.16+ compositor fixes";
    changelog = "https://github.com/alvr-org/ALVR/commit/${rev}";
    # Upstream's streamer bundles an x86_64 OpenVR library and Vulkan manifest.
    platforms = [ "x86_64-linux" ];
  };
})
