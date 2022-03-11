.DUMMY: dev

URL=127.0.0.1
dev:
	zola serve -i 0.0.0.0 -u $(URL) -p 8080 &
	npx postcss sass/index.scss -o public/index.css -w
