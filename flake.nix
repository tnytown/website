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
            version = "next-2021-02-06";
            src = pkgs.fetchFromGitHub {
              owner = "getzola";
              repo = o.pname;
              rev = "a65a2d52c70def075d8b4ed4c57dfd81b1f96ba3";
              hash = "sha256-xBzKT6Fdo95b6qFahN+x7v078rFyCsaI0fPZeLLz+iY=";
            };
            cargoDeps = o.cargoDeps.overrideAttrs (lib.const {
              name = "${o.pname}-${version}-vendor.tar.gz";
              inherit src;
              outputHash = "sha256-N79lrFqugJCky43bAKVPumNPqq9DECbmNtdNJR4T0oE=";
            });
          });
          texenv = (pkgs.texlive.combine {
            inherit (pkgs.texlive)
              scheme-small
              # color overrides, maybe unnecessary now
              xcolor
              # layout
              arydshln multirow enumitem
              # lua ...
              luatex
              luacode
              # fonts
              mathpazo ebgaramond fontawesome5 academicons
              # documentclass
              moderncv;
          });
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ texenv tectonic zolaNext nodejs nodePackages.node2nix ];
        };
        packages = rec {
          texdbg = pkgs.mkShell {
            buildInputs = [ texenv ];
          };
          cv = pkgs.stdenvNoCC.mkDerivation {
            name = "cv";
            src = pkgs.nix-gitignore.gitignoreSource [] ./.;
            buildInputs = [ texenv ];

            phases = [ "buildPhase" ];
            # YOLO
            # TODO(tny): can we cache this?
            TEXMFHOME = "/tmp/.texlive";
            TEXMFVAR = "/tmp/.texlive/texmf-var";

            buildPhase = ''
                echo \"${self.shortRev or "HEAD"}\" >rev.json
                lualatex $src/cv.tex
                mkdir -p $out && mv cv.pdf $out/
            '';
          };

          site = pkgs.stdenvNoCC.mkDerivation {
            name = "site";
            src = pkgs.nix-gitignore.gitignoreSource [] ./.;

            buildInputs = with pkgs; [ zolaNext nodejs ];
            phases = [ "unpackPhase" "buildPhase" ];
            buildPhase = ''
            ln -s ${nodeDeps}/lib/node_modules ./node_modules
            export PATH="${nodeDeps}/bin:$PATH"

            npx postcss --env production sass/index.scss -o static/index.css
            cp ${cv}/cv.pdf static/
            echo \"${self.shortRev or "HEAD"}\" >rev.json
            zola build -o $out
          '';
          };
        };
      });
}
