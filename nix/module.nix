{ self, ... }:

{ config, pkgs, lib, ... }:
let
  cfg = config.services.nextcloud2ntfy;
in {
  options = {
    services.nextcloud2ntfy = {
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
        type = lib.types.bool;
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
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          URL for heartbeat
        '';
      };

      heartbeat_interval = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
        description = ''
          Heartbeat interval in seconds
        '';
      };

      nextcloud_poll_interval_seconds = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 60;
        description = ''
          Nextcloud poll interval in seconds
        '';
      };

      nextcloud_error_sleep_seconds = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 600;
        description = ''
          Nextcloud sleep seconds on error
        '';
      };

      nextcloud_204_sleep_seconds = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 3600;
      };

      rate_limit_sleep_seconds = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 60;
        description = ''
          Rate limit sleep seconds
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = self.packages."${pkgs.system}".default;
        description = ''
          The nextcloud2ntfy package to use
        '';
      };
    };
  };

  config = let
    configFile = (pkgs.formats.json {}).generate "config.json" {
      ntfy_base_url = cfg.base_url;
      ntfy_topic = cfg.topic;
      ntfy_auth = cfg.auth;
      ntfy_token = cfg.token;

      nextcloud_base_url = cfg.nextcloud_base_url;

      nextcloud_username = cfg.nextcloud_username;
      nextcloud_password = cfg.nextcloud_password;

      heartbeat = cfg.heartbeat or false;
      heartbeat_url = cfg.heartbeat_url or "";
      heartbeat_interval = cfg.heartbeat_interval or 600;

      nextcloud_poll_interval_seconds = cfg.nextcloud_poll_interval_seconds;
      nextcloud_error_sleep_seconds = cfg.nextcloud_error_sleep_seconds;
      nextcloud_204_sleep_seconds = cfg.nextcloud_204_sleep_seconds;

      rate_limit_sleep_seconds = cfg.rate_limit_sleep_seconds;
    };
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
}
