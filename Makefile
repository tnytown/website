.DUMMY: dev n2n

n2n:
	node2nix --development -l package-lock.json -c node-attrs.nix

dev:
	zola serve &
	npx postcss sass/index.scss -o public/index.css -w
