let
  nextcloud_username = "user";
  nextcloud_password = "pass";

  nextcloud_admin_pass = "ncadminpass";

  ntfy_port = "2567";
in
(import ./lib.nix) {

  name = "from-nixos";

  nodes = {
    # self here is set by using specialArgs in `lib.nix`
    n2n = { self, ... }: {
      imports = [ self.nixosModules.nextcloud2ntfy ];

      services.nextcloud2ntfy = {
        enable = true;

        base_url = "ntfy";
        topic = "test";
        auth = false;
        token = "";
        nextcloud_base_url = "nextcloud";
        inherit nextcloud_username;
        inherit nextcloud_password;
      };
    };

    ntfy = { self, pkgs, ... }: {
      services.ntfy-sh = {
        enable = true;
        settings = {
          base-url = "ntfy";
          listen-http = ":${ntfy_port}";
          behind-proxy = false;
          auth-default-access = "allow-all";
        };
      };

      environment.systemPackages = [ pkgs.curl ];
    };

    nextcloud = { self, pkgs, config, ... }: {
      networking.firewall.allowedTCPPorts = [ 80 ];
      services.nextcloud = {
        enable = true;
        https = false;
        database.createLocally = pkgs.lib.mkDefault true;
        hostName = "nextcloud";
        config = {
          dbtype = "sqlite";
          adminpassFile = "${pkgs.writeText "adminpass" nextcloud_admin_pass}";
        };
      };
    };
  };

  testScript = ''
    start_all()
    nextcloud.wait_for_unit("multi-user.target")
    ntfy.wait_for_unit("multi-user.target")
    n2n.wait_for_unit("multi-user.target")

    with subtest("Ensure ntfy-sh server is working"):
        ntfy.succeed("curl -d 'test' http://localhost:${ntfy_port}/test")

    with subtest("Ensure nextcloud-occ is working"):
        nextcloud.succeed("nextcloud-occ status")
  '';
}
