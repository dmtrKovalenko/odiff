# Benchmark studio

Run the benchmark with any difference tool you want. This guide shows how to run the benchmark via [hyperfine](https://github.com/sharkdp/hyperfine). Make sure it is installed.

## Install the tools to benchmarks

Make sure you installed `odiff`, `pixelmatch` and `ImageMagick` (at least for this guide)

## Install the benchmark tool

We are using [hyperfine](https://github.com/sharkdp/hyperfine) to run performance tests. Follow the installation instructions on their [github](https://github.com/sharkdp/hyperfine). On MacOS you can do:

```
brew install hyperfine
```

## Run the benchmark

> Make sure that provided benchmark results were achieved on MacBook Pro 16, MacOS 11 BigSure beta.

Simple benchmark that compares [4k water image](./water-4k.png) with [corrupted one](./water-4k-2.png).

```
hyperfine -i 'odiff water-4k.png water-4k-2.png water-diff.png'  'pixelmatch water-4k.png water-4k-2.png water-diff.png' 'compare water-4k.png water-4k-2.png -compose src water-diff.png'

```

## Generate markdown results

This generates markdown output that is displayed in README.

```
hyperfine -i --export-markdown <PATH_TO_MARKDOWN> 'pixelmatch www.cypress.io-1.png www.cypress.io.png www.cypress-diff.png' 'compare www.cypress.io-1.png www.cypress.io.png -compose src diff-magick.png' 'ODiffBin www.cypress.io-1.png www.cypress.io.png www.cypress-diff.png'
```
