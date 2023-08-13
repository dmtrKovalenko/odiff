![Build and test the esy
package]()

# esy-libspng

`esy-libspng` is sample package, [`libspng`](https://github.com/randy408/libspng), packaged for [`esy`](https://esy.sh/).

## Why
`esy` can not only fetch and install Reason and OCaml libraries and tools,
but also those written in C. This extends reproducibility benefits to
packages written in C, like `skia`, `libffi`, `pkg-config`
etc. Users don't have to install them separately, nor have to worry if
they have installed the correct version. Read more at the docs about
[benefits for opting for esy packages](https://esy.sh#TODO).

## How to use `esy-libspng`?

`esy-libspng` can be used from both NPM and directly from Github.

### From NPM 

`esy-libspng` is deployed on NPM can be found
[here](https://www.npmjs.com/package/TODO).

You can simply run `esy add esy-libspng` to install it, or specify it in
`package.json` and run `esy`.

```diff
{
  "dependencies": {
+   "esy-libspng": "*"
  }
}
```

### Directly from Github

```json
{
  "dependencies": {
    "esy-libspng": "esy-packages/esy-libspng"
  }
}
```

i.e. `<GITHUB_ORG or USERNAME>/<REPO NAME>`

To use a specific commit,

```diff
  "dependencies": {
+   "esy-libspng": "esy-packages/esy-libspng#<commit hash>"
  }
```

## How to package for esy?

### For the experienced

**The gist**
Specify the configure and build commands in `esy.build` property of
`esy.json` and the install step in `esy.install`. If the package
builds "in source", set `esy.buildsInSource` property to `true`. Use
`$cur__install` environment variable to set the install location.

See [docs](TODO) for reference.

The CI will take care of fetching the sources and creating an NPM
package for you. See [script.js](TODO) to see how it works.

You can download it or auto publish via CI.

### For beginners

> Note: you'll need Node.js for this tutorial. If you're experienced
> with bash, you can use it instead.

Fundamentally, packaging for esy works like in other Linux distros,
except ofcourse, such that packages become available on MacOS and
Windows too.

You would typically have to specify the instructions to build the
package in the `esy.json`. For example, everyone's favourite http
tool, [curl](https://curl.se/), needs the following instructions ([as
described on their website](https://curl.se/docs/install.html))

```sh
./configure
make
make install
```

Many packages have similar instructions!

Configure and build steps are specified in the `esy.build` property in
the `esy.json` and install steps in `esy.install`. Example,

```json
{
  "esy": {
    "build": [
	  "./configure",
	  "make"
	],
	"install": [
	  "make install"
	]
  }
}
```


## Testing and making sure the package works as expected 

To test if the package works, we recommend an end-to-end test by
publishing it to local
[`verdaccio`](https://github.com/verdaccio/verdaccio), and using the
package with a `package.json` or `esy.json` depends on it.

```json
{
  "dependencies": {
    esy-libspng": "*"
  }
}
```

And pointing `esy` to the local npm registry

```sh
esy i --npm-registry http://localhost:4873
esy b
```

If the package is a library, it's a good idea to write a small program
to actually check if the library works. Referring how the
corresponding package is being tested in Homebrew or Arch Linux.

# Credits

This package borrow its manifest heavily from https://github.com/eWert-Online/esy-libspng
