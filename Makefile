.DUMMY: dev n2n

n2n:
	node2nix --development -l package-lock.json -c nix/node-attrs.nix -e nix/node-env.nix -o nix/node-packages.nix

URL=127.0.0.1
dev:
	zola serve -i 0.0.0.0 -u $(URL) -p 8080 &
	npx postcss sass/index.scss -o public/index.css -w
