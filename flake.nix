{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11-small";
    unstable.url = "nixpkgs/nixos-unstable-small";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, unstable, utils }: utils.lib.eachDefaultSystem
    (system:
      let pkgs = nixpkgs.legacyPackages.${system};
          unstablePkgs = unstable.legacyPackages.${system};
          lib = nixpkgs.lib;
          yarnDeps = pkgs.mkYarnPackage rec {
            name = "site-styles";
            src = ./.;
            packageJSON = "${src}/package.json";
            yarnLock = "${src}/yarn.lock";
	    dontStrip = true;
	    dontFixup = true;
          };
          texenv = (pkgs.texlive.combine {
            inherit (pkgs.texlive)
              scheme-small
              # color overrides, maybe unnecessary now
              xcolor
              # tikz
              pgf
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
	  zola = unstablePkgs.zola;
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
                cat <<EOF >rev.json
                {
                    "rev": "${self.shortRev or "HEAD"}",
                    "modified": ${builtins.toString self.lastModified}
                }
                EOF
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
            HOME=$(mktemp -d)
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
