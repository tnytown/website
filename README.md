website
=======

Andrew Pan's blog. Built with Nix Flakes and Zola, styled with Tailwind CSS.

## Useful commands

### Development
The `Makefile` includes a handy zola + postcss invocation. It's a bit finicky because it backgrounds
Zola, but it works out most of the time. Hot reloads work.

``` sh
make dev
```

### Building for production

``` sh
nix -L build .#
```

Check out how it looks in `result/`.

### Pinning node dependencies with Nix after updates

``` sh
node2nix -d -l package-lock.json -c node-attrs.nix
```

The `-d` option specifies that you explicitly want to install development dependencies, which makes sense because we're building the site. This is important to remember.

Usually, you'd want to run this after `npm audit` to fix "vulnerabilities" like regular expression 
DoS in development dependencies.

Additionally, the `Makefile` previously mentioned includes this command. In that case, just run

``` sh
make n2n
```

and you're home free.
