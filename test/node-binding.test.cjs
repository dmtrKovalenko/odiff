const path = require("path");
const test = require("ava");
const { compare } = require("../npm_package/odiff");

const IMAGES_PATH = path.resolve(__dirname, "..", "images");
const BINARY_PATH = path.resolve(
  __dirname,
  "..",
  "_build",
  "default",
  "bin",
  "ODiffBin.exe"
);

console.log(`Testing binary ${BINARY_PATH}`);

const options = {
  __binaryPath: BINARY_PATH,
}

test("Outputs correct parsed result when images different", async (t) => {
  const { reason, diffCount, diffPercentage } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    options
  );

  t.is(reason, "pixel-diff");
  t.is(diffCount, 101841);
  t.is(diffPercentage, 2.65077570347);
})

test("Correctly works with reduceRamUsage", async (t) => {
  const { reason, diffCount, diffPercentage } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      ...options,
      reduceRamUsage: true,
    }
  );

  t.is(reason, "pixel-diff");
  t.is(diffCount, 101841);
  t.is(diffPercentage, 2.65077570347);
});

test("Correctly parses threshold", async (t) => {
  const { reason, diffCount, diffPercentage } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      ...options,
      threshold: 0.5,
    }
  );

  t.is(reason, "pixel-diff");
  t.is(diffCount, 65357);
  t.is(diffPercentage, 1.70114931758);
});

test("Correctly parses antialiasing", async (t) => {
  const { reason, diffCount, diffPercentage } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      ...options,
      antialiasing: true,
    }
  );

  t.is(reason, "pixel-diff");
  t.is(diffCount, 101499);
  t.is(diffPercentage, 2.64187393218);
});

test("Correctly parses ignore regions", async (t) => {
  const { match } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      ...options,
      ignoreRegions: [
        {
          x1: 749,
          y1: 1155,
          x2: 1170,
          y2: 1603,
        },
        {
          x1: 657,
          y1: 1278,
          x2: 742,
          y2: 1334,
        },
      ],
    }
  );

  t.is(match, true);
});

test("Outputs correct parsed result when images different for cypress image", async (t) => {
  const { reason, diffCount, diffPercentage } = await compare(
    path.join(IMAGES_PATH, "www.cypress.io.png"),
    path.join(IMAGES_PATH, "www.cypress.io-1.png"),
    path.join(IMAGES_PATH, "diff.png"),
    options
  );

  t.is(reason, "pixel-diff");
  t.is(diffCount, 1091034);
  t.is(diffPercentage, 2.95123808559);
});

test("Correctly handles same images", async (t) => {
  const { match } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "diff.png"),
    options
  );

  t.is(match, true);
});

test("Correctly outputs diff lines", async (t) => {
  const { match, diffLines } = await compare(
    path.join(IMAGES_PATH, "donkey.png"),
    path.join(IMAGES_PATH, "donkey-2.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      captureDiffLines: true,
      ...options
    }
  );

  t.is(match, false);
  t.is(diffLines.length, 402);
});

test("Returns meaningful error if file does not exist and noFailOnFsErrors", async (t) => {
  const { match, reason, file } = await compare(
    path.join(IMAGES_PATH, "not-existing.png"),
    path.join(IMAGES_PATH, "not-existing.png"),
    path.join(IMAGES_PATH, "diff.png"),
    {
      ...options,
      noFailOnFsErrors: true,
    }
  );

  t.is(match, false);
  t.is(reason, "file-not-exists");
  t.is(file, path.join(IMAGES_PATH, "not-existing.png"));
});
