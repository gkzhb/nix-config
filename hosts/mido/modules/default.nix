{ pkgs, ... }:

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
      git
      just
      neovim
      ripgrep
      tmux
      yazi
      zoxide
      mosquitto
    ];

    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    # This replaces the apk sample configuration. It listens on every
    # available interface; remote access is anonymous until credentials, ACLs,
    # and TLS are configured here.
    environment.etc."mosquitto/mosquitto.conf" = {
      replaceExisting = true;
      text = ''
        listener 1883
        allow_anonymous true

        persistence true
        persistence_location /var/lib/mosquitto/

        log_dest stdout
      '';
    };

    systemd.services.battery-reporter = {
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

    systemd.timers.battery-reporter = {
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

    # Both the broker binary and its configuration are declaratively managed.
    # This currently permits anonymous connections from every reachable host.
    systemd.services.mosquitto = {
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
}
