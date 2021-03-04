.DUMMY: dev

dev:
	zola serve &
	npx postcss sass/index.scss -o public/index.css -w
