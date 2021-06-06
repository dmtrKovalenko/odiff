open TestFramework;
open ODiffIO;

module Diff = Odiff.Diff.MakeDiff(PureC_IO.IO, PureC_IO.IO);
module AADiff =
  Odiff.Diff.MakeDiff(PureC_IO_Bigarray.IO, PureC_IO_Bigarray.IO);

describe("Png comparing", ({test, _}) => {
  test("finds difference between 2 images", ({expect, _}) => {
    let img1 = PureC_IO.IO.loadImage("test/test-images/orange.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/orange_changed.png");

    let (_, diffPixels, diffPercentage) = Diff.compare(img1, img2, ());

    expect.int(diffPixels).toBe(1430);
    expect.float(diffPercentage).toBeCloseTo(1.20);
  });

  test("uses provided threshold", ({expect, _}) => {
    let img1 = PureC_IO.IO.loadImage("test/test-images/orange.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/orange_changed.png");

    let (_, diffPixels, diffPercentage) =
      Diff.compare(img1, img2, ~threshold=0.5, ());
    expect.int(diffPixels).toBe(222);
    expect.float(diffPercentage).toBeCloseTo(0.19);
  });

  test("uses provided irgnore regions", ({expect, _}) => {
    let img1 = PureC_IO.IO.loadImage("test/test-images/orange.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/orange_changed.png");

    let (_diffOutput, diffPixels, diffPercentage) =
      Diff.compare(
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
  });

  test("creates the right diff output image", ({expect, _}) => {
    let img1 = PureC_IO.IO.loadImage("test/test-images/orange.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/orange_changed.png");

    let (diffOutput, _, _) = Diff.compare(img1, img2, ());

    let originalDiff =
      PureC_IO.IO.loadImage("test/test-images/orange_diff.png");
    let (diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage) =
      Diff.compare(originalDiff, diffOutput, ());

    if (diffOfDiffPixels > 0) {
      PureC_IO.IO.saveImage(diffOutput, "test/test-images/diff-output.png");
      PureC_IO.IO.saveImage(
        diffMaskOfDiff,
        "test/test-images/diff-of-diff.png",
      );
    };

    expect.int(diffOfDiffPixels).toBe(0);
    expect.float(diffOfDiffPercentage).toBeCloseTo(0.0);
  });

  test(
    "creates the right diff output image with custom diff color",
    ({expect, _}) => {
    let img1 = PureC_IO.IO.loadImage("test/test-images/orange.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/orange_changed.png");

    let (diffOutput, _, _) =
      Diff.compare(img1, img2, ~diffPixel=(0, 255, 0), ());

    let originalDiff =
      PureC_IO.IO.loadImage("test/test-images/orange_diff_green.png");
    let (diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage) =
      Diff.compare(originalDiff, diffOutput, ());

    if (diffOfDiffPixels > 0) {
      PureC_IO.IO.saveImage(
        diffOutput,
        "test/test-images/diff-output-green.png",
      );
      PureC_IO.IO.saveImage(
        diffMaskOfDiff,
        "test/test-images/diff-of-diff-green.png",
      );
    };

    expect.int(diffOfDiffPixels).toBe(0);
    expect.float(diffOfDiffPercentage).toBeCloseTo(0.0);
  });

  test("does not count anti-aliased pixels as different", ({expect, _}) => {
    let img1 =
      PureC_IO_Bigarray.IO.loadImage("test/test-images/antialiasing-on.png");
    let img2 =
      PureC_IO_Bigarray.IO.loadImage("test/test-images/antialiasing-off.png");

    let (_, diffPixels, diffPercentage) =
      AADiff.compare(
        img1,
        img2,
        ~outputDiffMask=true,
        ~antialiasing=true,
        (),
      );

    expect.int(diffPixels).toBe(38);
    expect.float(diffPercentage).toBeCloseTo(0.095);
  });

  test("Diff of mask and no mask are equal", ({expect, _}) => {
    let img1 = PureC_IO.IO.loadImage("test/test-images/antialiasing-on.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/antialiasing-off.png");

    let (_, diffPixels, diffPercentage) =
      Diff.compare(img1, img2, ~outputDiffMask=false, ());

    let img1 = PureC_IO.IO.loadImage("test/test-images/antialiasing-on.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/antialiasing-off.png");

    let (_, diffPixelsMask, diffPercentageMask) =
      Diff.compare(img1, img2, ~outputDiffMask=true, ());

    expect.int(diffPixels).toBe(diffPixelsMask);
    expect.float(diffPercentage).toBeCloseTo(diffPercentageMask);
  });

  test("tests diffrent sized AA images", ({expect, _}) => {
    let img1 =
      PureC_IO_Bigarray.IO.loadImage("test/test-images/antialiasing-on.png");
    let img2 =
      PureC_IO_Bigarray.IO.loadImage(
        "test/test-images/antialiasing-off-small.png",
      );

    let (_, diffPixels, diffPercentage) =
      AADiff.compare(
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
