{
  inputs = {
    nixpkgs.url = "nixpkgs/release-21.05";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem
    (system:
      let pkgs = nixpkgs.legacyPackages.${system};
          nodeDeps = (pkgs.callPackage ./nix/node-attrs.nix {}).shell.nodeDependencies;
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ zola nodejs pandoc nodePackages.node2nix ];
        };
        packages.site = pkgs.stdenv.mkDerivation {
          name = "site";
          src = pkgs.nix-gitignore.gitignoreSource [] ./.;

          buildInputs = with pkgs; [ zola nodejs ];
          phases = [ "unpackPhase" "buildPhase" ];
          buildPhase = ''
            ln -s ${nodeDeps}/lib/node_modules ./node_modules
            export PATH="${nodeDeps}/bin:$PATH"

            npx postcss --env production sass/index.scss -o static/index.css
            echo \"${self.shortRev or "unknown"}\" >rev.json
            zola build -o $out
          '';
        };
      });
}
