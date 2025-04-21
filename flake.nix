{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs:
    ({
      nixosModules.nextcloud2ntfy = import ./nix/module.nix {
        inherit (inputs) self;
      };
    } //
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
      checks = let
        checkArgs = {
          # reference to nixpkgs for the current system
          pkgs = inputs.nixpkgs.legacyPackages.${system};

          # this gives us a reference to our flake but also all flake inputs
          inherit (inputs) self;
        };
      in {
        start-test = import ./tests/start-test.nix checkArgs;
      };

      packages.default = nextcloud2ntfy;

      devShells.cloudroots = pkgs.mkShell {
        inherit buildInputs;
      };
    })
  );
}
