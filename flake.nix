{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays =
          let
            selfOverlay = _: _: { } // inputs.self.packages."${system}";
          in
          [
            selfOverlay
          ];
      };

      buildInputs = [
        pkgs.python3Packages.requests
      ];

      nextcloud2ntfy = pkgs.python3Packages.buildPythonPackage {
        pname = "nextcloud2ntfy";
        version = "1.1.1";

        src = ./.;

        preBuild = ''
          cat > setup.py << EOF
          from setuptools import setup

          with open('requirements.txt') as f:
            install_requires = f.read().splitlines()

          setup(
            name='nextcloud2ntfy',
            #packages=['someprogram'],
            version='0.1.0',
            #author='...',
            #description='...',
            install_requires=install_requires,
            scripts=[
              'nextcloud2ntfy.py',
            ],
            entry_points={
              # example: file some_module.py -> function main
              'console_scripts': ['nextcloud2ntfy=nextcloud2ntfy:main']
            },
          )
          EOF

          cat setup.py
        '';

        inherit buildInputs;

        installPhase = ''
          mkdir -p $out/bin
          cp -v ./nextcloud2ntfy.py $out/bin/
          chmod +x $out/bin/nextcloud2ntfy.py
        '';
      };
    in {
      packages.default = nextcloud2ntfy;

      nixosModules.nextcloud2ntfy = { config, pkgs }:
      let
        lib = pkgs.lib;
        cfg = config.nextcloud2ntfy;
      in {
        options = {
          enable = lib.mkEnableOption "nextcloud2ntfy";

          user = lib.mkOption {
            type = lib.types.str;
            default = "nextcloud2ntfy";
          };

          group = lib.mkOption {
            type = lib.types.str;
            default = "nextcloud2ntfy";
          };

          base_url = lib.mkOption {
            type = lib.types.str;
            example = "https://ntfy.sh";
            description = ''
              The base URL
            '';
          };

          topic = lib.mkOption {
            default = "nextcloud";
            description = ''
              The topic to publish notifications on
            '';
          };

          auth = lib.mkOption {
            type = lib.types.boolean;
            default = false;
            description = ''
              Use authentication with the ntfy server
            '';
          };

          token = lib.mkOption {
            type = lib.types.str;
            description = ''
              The auth token
            '';
          };

          nextcloud_base_url = lib.mkOption {
            example = "https://nextcloud.example.com";
            description = ''
              URL of the nextcloud server
            '';
          };

          nextcloud_username = lib.mkOption {
            example = "user";
            description = ''
              Nextcloud user name
            '';
          };

          nextcloud_password = lib.mkOption {
            type = lib.types.str;
            example = "application_password";
            description = ''
              Nextcloud user password
            '';
          };

          heartbeat = lib.mkOption {
            default = false;
            description = ''
              Whether to use heartbeat
            '';
          };

          heartbeat_url = lib.mkOption {
            type = lib.types.str;
            description = ''
              URL for heartbeat
            '';
          };

          heartbeat_interval = lib.mkOption {
            type = lib.types.unsigned;
            default = 30;
            description = ''
              Heartbeat interval in seconds
            '';
          };

          nextcloud_poll_interval_seconds = lib.mkOption {
            type = lib.types.unsigned;
            default = 60;
            description = ''
              Nextcloud poll interval in seconds
            '';
          };

          nextcloud_error_sleep_seconds = lib.mkOption {
            type = lib.types.unsigned;
            default = 600;
            description = ''
              Nextcloud sleep seconds on error
            '';
          };

          nextcloud_204_sleep_seconds = lib.mkOption {
            type = lib.types.unsigned;
            default = 3600;
          };

          rate_limit_sleep_seconds = lib.mkOption {
            type = lib.types.unsigned;
            default = 60;
            description = ''
              Rate limit sleep seconds
            '';
          };

          package = lib.mkOption {
            type = lib.types.package;
            default = nextcloud2ntfy;
            description = ''
              The nextcloud2ntfy package to use
            '';
          };
        };

        config = let
          configFile = pkgs.writeFile "config.json" (pkgs.formats.toJSON {
            ntfy_base_url = cfg.ntfy_base_url;
            ntfy_topic = cfg.ntfy_topic;
            ntfy_auth = cfg.ntfy_auth;
            ntfy_token = cfg.ntfy_token;

            nextcloud_base_url = cfg.nextcloud_base_url;

            nextcloud_username = cfg.nextcloud_username;
            nextcloud_password = cfg.nextcloud_password;

            heartbeat = cfg.heartbeat;
            heartbeat_url = cfg.heartbeat_url;
            heartbeat_interval = cfg.heartbeat_interval;

            nextcloud_poll_interval_seconds = cfg.nextcloud_poll_interval_seconds;
            nextcloud_error_sleep_seconds = cfg.nextcloud_error_sleep_seconds;
            nextcloud_204_sleep_seconds = cfg.nextcloud_204_sleep_seconds;

            rate_limit_sleep_seconds = cfg.rate_limit_sleep_seconds;
          });
        in (lib.mkIf cfg.enable {
          systemd.services.foundryvtt = {
            description = "nextcloud2ntfy";

            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              User = cfg.user;
              Group = cfg.group;
              Restart = "always";
              ExecStart = "${cfg.package}/bin/nextcloud2nix.py --config-file ${configFile}";
              StateDirectory = "nextcloud2ntfy";
              StateDirectoryMode = "0750";

              # Hardening
              CapabilityBoundingSet = [
                "AF_NETLINK"
                "AF_INET"
                "AF_INET6"
              ];
              DeviceAllow = [ "/dev/stdin r" ];
              DevicePolicy = "strict";
              IPAddressAllow = "localhost";
              LockPersonality = true;
              # MemoryDenyWriteExecute = true;
              NoNewPrivileges = true;
              PrivateDevices = true;
              PrivateTmp = true;
              PrivateUsers = true;
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHome = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectSystem = "strict";
              ReadOnlyPaths = [ "/" ];
              RemoveIPC = true;
              RestrictAddressFamilies = [
                "AF_NETLINK"
                "AF_INET"
                "AF_INET6"
              ];
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
              SystemCallFilter = [
                "@system-service"
                "~@privileged"
                "~@resources"
                "@pkey"
              ];
              UMask = "0027";
            };
          };
        });
      };

      devShells.cloudroots = pkgs.mkShell {
        inherit buildInputs;
      };
    });
}
