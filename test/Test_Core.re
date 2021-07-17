open TestFramework;
open ODiffIO;

module PNG_Diff = Odiff.Diff.MakeDiff(Png.IO, Png.IO);
module PNG_BA_Diff = Odiff.Diff.MakeDiff(Png.BigarrayIO, Png.BigarrayIO);

describe("CORE: Antialiasing", ({test, _}) => {
  open Png.BigarrayIO;

  test("does not count anti-aliased pixels as different", ({expect, _}) => {
    let img1 = loadImage("test/test-images/aa/antialiasing-on.png");
    let img2 = loadImage("test/test-images/aa/antialiasing-off.png");

    let (_, diffPixels, diffPercentage) =
      PNG_BA_Diff.compare(
        img1,
        img2,
        ~outputDiffMask=true,
        ~antialiasing=true,
        (),
      );

    expect.int(diffPixels).toBe(38);
    expect.float(diffPercentage).toBeCloseTo(0.095);
  });

  test("tests diffrent sized AA images", ({expect, _}) => {
    let img1 = loadImage("test/test-images/aa/antialiasing-on.png");
    let img2 = loadImage("test/test-images/aa/antialiasing-off-small.png");

    let (_, diffPixels, diffPercentage) =
      PNG_BA_Diff.compare(
        img1,
        img2,
        ~outputDiffMask=true,
        ~antialiasing=true,
        (),
      );

    expect.int(diffPixels).toBe(417);
    expect.float(diffPercentage).toBeCloseTo(1.04);
  });
});

describe("CORE: Threshold", ({test, _}) => {
  test("uses provided threshold", ({expect, _}) => {
    let img1 = Png.IO.loadImage("test/test-images/png/orange.png");
    let img2 = Png.IO.loadImage("test/test-images/png/orange_changed.png");

    let (_, diffPixels, diffPercentage) =
      PNG_Diff.compare(img1, img2, ~threshold=0.5, ());
    expect.int(diffPixels).toBe(222);
    expect.float(diffPercentage).toBeCloseTo(0.19);
  })
});

describe("CORE: Ignore Regions", ({test, _}) => {
  test("uses provided irgnore regions", ({expect, _}) => {
    let img1 = Png.IO.loadImage("test/test-images/png/orange.png");
    let img2 = Png.IO.loadImage("test/test-images/png/orange_changed.png");

    let (_diffOutput, diffPixels, diffPercentage) =
      PNG_Diff.compare(
        img1,
        img2,
        ~ignoreRegions=[
          ((150, 30), (310, 105)),
          ((20, 175), (105, 200)),
        ],
        (),
      );

    expect.int(diffPixels).toBe(0);
    expect.float(diffPercentage).toBeCloseTo(0.0);
  })
});

describe("CORE: Diff Color", ({test, _}) => {
  test("creates diff output image with custom diff color", ({expect, _}) => {
    let img1 = Png.IO.loadImage("test/test-images/png/orange.png");
    let img2 = Png.IO.loadImage("test/test-images/png/orange_changed.png");

    let (diffOutput, _, _) =
      PNG_Diff.compare(img1, img2, ~diffPixel=(0, 255, 0), ());

    let originalDiff =
      Png.IO.loadImage("test/test-images/png/orange_diff_green.png");
    let (diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage) =
      PNG_Diff.compare(originalDiff, diffOutput, ());

    if (diffOfDiffPixels > 0) {
      Png.IO.saveImage(
        diffOutput,
        "test/test-images/png/diff-output-green.png",
      );
      Png.IO.saveImage(
        diffMaskOfDiff,
        "test/test-images/png/diff-of-diff-green.png",
      );
    };

    expect.int(diffOfDiffPixels).toBe(0);
    expect.float(diffOfDiffPercentage).toBeCloseTo(0.0);
  })
});
