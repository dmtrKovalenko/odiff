const path = require("path");
const test = require("ava");
const { compare } = require("../bin/node-bindings/odiff");

const IMAGES_PATH = path.resolve(__dirname, "..", "images");
const BINARY_PATH = path.resolve(
  __dirname,
  "..",
  "_esy",
  "default",
  "build-release",
  "default",
  "bin",
  "ODiffBin.exe"
);

console.log(`Testing binary ${BINARY_PATH}`)

test("Outputs correct parsed result when images different", async (t) => {
  const { reason, diffCount, diffPercentage } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      __binaryPath: BINARY_PATH,
    }
  )

  t.is(reason, 'pixel-diff')
  t.is(diffCount, 109861);
  t.is(diffPercentage, 2.85952484323);
});

test("Correctly parses threshold", async (t) => {
  const { reason, diffCount, diffPercentage } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      threshold: 0.6,
      __binaryPath: BINARY_PATH,
    }
  )

  t.is(reason, 'pixel-diff')
  t.is(diffCount, 50332);
  t.is(diffPercentage, 1.31007003768);
});

test("Correctly parses antialiasing", async (t) => {
  const { reason, diffCount, diffPercentage } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      antialiasing: true,
      __binaryPath: BINARY_PATH,
    }
  )

  t.is(reason, 'pixel-diff')
  t.is(diffCount, 108208);
  t.is(diffPercentage, 2.8164996153);
});

test("Correctly parses ignore regions", async (t) => {
  const { match } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      ignoreRegions: [
        {
          x1: 749,  y1: 1155,
          x2: 1170, y2: 1603,
        },
        {
          x1: 657, y1: 1278,
          x2: 742, y2: 1334,
        }
      ],
      __binaryPath: BINARY_PATH,
    }
  )

  t.is(match, true);
});

test("Outputs correct parsed result when images different for cypress image", async (t) => {
  const { reason, diffCount, diffPercentage } = await compare(
    path.join(IMAGES_PATH, "www.cypress.io.png"),
    path.join(IMAGES_PATH, "www.cypress.io-1.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      __binaryPath: BINARY_PATH,
    }
  )

  t.is(reason, 'pixel-diff')
  t.is(diffCount, 1091034);
  t.is(diffPercentage, 2.95123808559);
});

test("Correctly handles same images", async (t) => {
  const { match } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      __binaryPath: BINARY_PATH,
    }
  )

  t.is(match, true)
});
