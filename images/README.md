# Benchmark studio

Run the benchmark with any difference tool you want. This guide shows how to run the benchmark via [hyperfine](https://github.com/sharkdp/hyperfine). Make sure it is installed.

## Install the diffs

Make sure you installed `odiff`, `pixelmatch` and `ImageMagick` (at least for this guide)

## Run the benchmark

Simple benchmark that compares [4k water image](./water-4k.png) with [corrupted one](./water-4k-2.png).

```
hyperfine -i 'odiff water-4k.png water-4k-2.png water-diff.png'  'pixelmatch water-4k.png water-4k-2.png water-diff.png' 'compare water-4k.png water-4k-2.png -compose src water-diff.png'

```

## Generate markdown results

This generates markdown output, that is displayed in README

```
hyperfine -i --export-markdown <PATH_TO_MARKDOWN> 'pixelmatch www.cypress.io-1.png www.cypress.io.png www.cypress-diff.png' 'compare www.cypress.io-1.png www.cypress.io.png -compose src diff-magick.png' 'ODiffBin www.cypress.io-1.png www.cypress.io.png www.cypress-diff.png'
```
