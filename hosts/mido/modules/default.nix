{ pkgs, ... }:

let
  # Keep system services' non-interactive PATH aligned with user tooling.
  servicePath = "PATH=/home/user/.local/share/pnpm/bin:/home/user/.local/bin:/home/user/.bun/bin:/home/user/go/bin:/home/user/scripts:/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
in
{
  config = {
    # postmarketOS is Alpine-derived, so it is outside system-manager's
    # supported distro set. This host has systemd as PID 1, which is required
    # by system-manager, but its system integration remains intentionally
    # limited to the global Nix package environment below.
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = "aarch64-linux";

    nix = {
      enable = true;
      package = pkgs.nix;
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [
          "user"
          "root"
        ];
      };
    };

    # The apk-provided nix-daemon and /etc/nix/nix.conf remain host-managed.
    # Do not set nix.* here: system-manager would otherwise take ownership of
    # host Nix configuration files.

    environment.systemPackages = with pkgs; [
      # Start with small, cache-friendly CLI tools. Add all globally exposed
      # Nix packages here; they appear through /run/system-manager/sw/bin.
      system-manager
      bat
      fd
      fish
      fzf
      just
      neovim
      ripgrep
      tmux
      yazi
      zoxide
      beads
      mosquitto

      # dev tools
      git
      clang
      ruff
      ty
      optnix
      nil
      nixfmt

      code-server
    ];

    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    # This replaces the apk sample configuration. It listens on every
    # available interface; remote access is anonymous until credentials, ACLs,
    # and TLS are configured here.
    environment.etc."mosquitto/mosquitto.conf" = {
      source = ./mosquitto.conf;
      replaceExisting = true;
    };

    # System services managed by system-manager.
    systemd = {
      # code-server must run through Nix's glibc Node on this Alpine-derived
      # host. LIBC=glibc prevents node-gyp-build from selecting argon2's musl
      # prebuild solely because /etc/alpine-release exists.
      services = {
        code-server = {
          description = "code-server for user";
          wantedBy = [ "system-manager.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            User = "user";
            Group = "user";
            WorkingDirectory = "/home/user";
            Environment = [
              "HOME=/home/user"
              "LIBC=glibc"
              servicePath
            ];
            ExecStart = "${pkgs.code-server}/bin/code-server --disable-telemetry --disable-update-check";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        # Tuya applications are maintained as user-owned scripts. Their setup
        # steps and long-running processes stay in those scripts; systemd
        # provides lifecycle management and the same runtime environment as
        # code-server.
        tuya-api = {
          description = "Tuya API service for user";
          wantedBy = [ "system-manager.target" ];
          requires = [ "mosquitto.service" ];
          after = [
            "network.target"
            "mosquitto.service"
          ];
          serviceConfig = {
            User = "user";
            Group = "user";
            WorkingDirectory = "/home/user/gitrep/tuya-controller-prod";
            Environment = [
              "HOME=/home/user"
              servicePath
            ];
            ExecStart = "/home/user/scripts/services/tuya-api.fish";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        tuya-controller = {
          description = "Tuya controller service for user";
          wantedBy = [ "system-manager.target" ];
          requires = [ "mosquitto.service" ];
          after = [
            "network.target"
            "mosquitto.service"
          ];
          serviceConfig = {
            User = "user";
            Group = "user";
            WorkingDirectory = "/home/user/gitrep/tuya-controller-prod";
            Environment = [
              "HOME=/home/user"
              servicePath
            ];
            ExecStart = "/home/user/scripts/services/tuya-controller.fish";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        battery-reporter = {
          description = "Report mido battery telemetry to MQTT";
          wants = [
            "network-online.target"
            "mosquitto.service"
          ];
          after = [
            "network-online.target"
            "mosquitto.service"
          ];
          # Makes node and mosquitto_pub available to ExecStart via PATH.
          path = [
            pkgs.nodejs
            pkgs.mosquitto
          ];
          serviceConfig = {
            Type = "oneshot";
            # Node.js runs this TypeScript file using its built-in type stripping.
            ExecStart = "node --experimental-strip-types ${./../scripts/report-battery.ts}";

            # mido's locally managed broker is the default destination. Override
            # these in a systemd drop-in if the telemetry should go to another
            # broker.
            Environment = [
              "MQTT_HOST=127.0.0.1"
              "MQTT_PORT=1883"
              "MQTT_TOPIC=device/mido/battery"
              "MQTT_QOS=1"
            ];

            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            ReadOnlyPaths = [ "/sys/class/power_supply" ];
          };
        };

        # Both the broker binary and its configuration are declaratively
        # managed. This currently permits anonymous connections from every
        # reachable host.
        mosquitto = {
          description = "Mosquitto MQTT broker";
          wantedBy = [ "system-manager.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            DynamicUser = true;
            StateDirectory = "mosquitto";
            ExecStart = "${pkgs.mosquitto}/bin/mosquitto -c /etc/mosquitto/mosquitto.conf";
            Restart = "on-failure";
          };
        };
      };

      timers.battery-reporter = {
        description = "Report mido battery telemetry every 15 minutes";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          Unit = "battery-reporter.service";
          OnCalendar = "*:0/15";
          Persistent = true;
          AccuracySec = "10s";
          RandomizedDelaySec = "0";
        };
      };
    };
  };
}
