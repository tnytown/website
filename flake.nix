{
  inputs = {
    nixpkgs.url = "nixpkgs/release-20.09";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem
    (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ zola ];
        };
        packages.site = pkgs.stdenv.mkDerivation {
          name = "site";
          src = self;

          buildInputs = with pkgs; [ zola ];
          dontInstall = true;
          buildPhase = ''
echo "${self.shortRev or "unknown"}" >rev.json
zola build -o $out'';
        };
      });
}
