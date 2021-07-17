{
  inputs = {
    nixpkgs.url = "nixpkgs/release-21.05";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem
    (system:
      let pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
          nodeDeps = (pkgs.callPackage ./nix/node-attrs.nix {}).shell.nodeDependencies;
          zolaNext = pkgs.zola.overrideAttrs(o: rec {
            # version = "next-2021-07-10";
            version = "next-2021-02-06";
            src = pkgs.fetchFromGitHub {
              owner = "getzola";
              repo = o.pname;
              rev = "a65a2d52c70def075d8b4ed4c57dfd81b1f96ba3";
              /*rev = "8c3ce7d7fbc0d585d4cbf27598ac7dfe5acd96f1";
              hash = "sha256-Tw3u96ZPb0yUXvtJ+rna6nnb0a+KfTEiR/PPEadFxDA=";*/
              hash = "sha256-xBzKT6Fdo95b6qFahN+x7v078rFyCsaI0fPZeLLz+iY=";
            };
            cargoDeps = o.cargoDeps.overrideAttrs (lib.const {
              name = "${o.pname}-${version}-vendor.tar.gz";
              inherit src;
              /*outputHash = "sha256-eJSu9p/6DJpS5j89OOkpYF3HF6uaJdqOl8zdvUrhGgc=";*/
              outputHash = "sha256-N79lrFqugJCky43bAKVPumNPqq9DECbmNtdNJR4T0oE=";
            });
          });
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ zolaNext nodejs nodePackages.node2nix ];
        };
        packages.site = pkgs.stdenv.mkDerivation {
          name = "site";
          src = pkgs.nix-gitignore.gitignoreSource [] ./.;

          buildInputs = with pkgs; [ zolaNext nodejs ];
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
