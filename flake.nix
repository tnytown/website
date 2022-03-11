{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem
    (system:
      let pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
          yarnDeps = pkgs.mkYarnPackage rec {
            name = "site-styles";
            src = ./.;
            packageJSON = "${src}/package.json";
            yarnLock = "${src}/yarn.lock";
          };
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
          buildInputs = with pkgs; [ texenv tectonic zola nodejs yarn ];
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

          inherit yarnDeps;
          site = pkgs.stdenvNoCC.mkDerivation {
            name = "site";
            src = pkgs.nix-gitignore.gitignoreSource [] ./.;

            buildInputs = with pkgs; [ zola nodejs ];
            phases = [ "unpackPhase" "buildPhase" ];
            buildPhase = ''
            ln -s ${yarnDeps}/libexec/website/node_modules .
            npx postcss --env production sass/index.scss -o static/index.css
            cp ${cv}/cv.pdf static/
            echo \"${self.shortRev or "HEAD"}\" >rev.json
            zola build -o $out
          '';
          };
        };
      });
}
