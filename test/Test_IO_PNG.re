open TestFramework;
open ODiffIO;

module Diff = Odiff.Diff.MakeDiff(Png.IO, Png.IO);

describe("IO: PNG", ({test, _}) => {
  open Png.IO;

  test("finds difference between 2 images", ({expect, _}) => {
    let img1 = loadImageFromPath("test/test-images/png/orange.png");
    let img2 = loadImageFromPath("test/test-images/png/orange_changed.png");

    let (_, diffPixels, diffPercentage) = Diff.compare(img1, img2, ());

    expect.int(diffPixels).toBe(1430);
    expect.float(diffPercentage).toBeCloseTo(1.20);
  });

  test("Diff of mask and no mask are equal", ({expect, _}) => {
    let img1 = loadImageFromPath("test/test-images/png/orange.png");
    let img2 = loadImageFromPath("test/test-images/png/orange_changed.png");

    let (_, diffPixels, diffPercentage) =
      Diff.compare(img1, img2, ~outputDiffMask=false, ());

    let img1 = loadImageFromPath("test/test-images/png/orange.png");
    let img2 = loadImageFromPath("test/test-images/png/orange_changed.png");

    let (_, diffPixelsMask, diffPercentageMask) =
      Diff.compare(img1, img2, ~outputDiffMask=true, ());

    expect.int(diffPixels).toBe(diffPixelsMask);
    expect.float(diffPercentage).toBeCloseTo(diffPercentageMask);
  });

  test("Creates correct diff output image", ({expect, _}) => {
    let img1 = loadImageFromPath("test/test-images/png/orange.png");
    let img2 = loadImageFromPath("test/test-images/png/orange_changed.png");

    let (diffOutput, _, _) = Diff.compare(img1, img2, ());

    let originalDiff =
      loadImageFromPath("test/test-images/png/orange_diff.png");
    let (diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage) =
      Diff.compare(originalDiff, diffOutput, ());

    if (diffOfDiffPixels > 0) {
      saveImage(diffOutput, "test/test-images/png/diff-output.png");
      saveImage(diffMaskOfDiff, "test/test-images/png/diff-of-diff.png");
    };

    expect.int(diffOfDiffPixels).toBe(0);
    expect.float(diffOfDiffPercentage).toBeCloseTo(0.0);
  });

  test("Can load images with a provided buffer", ({expect, _}) => {
    let img1 =
      TestUtils.getFileContents("test/test-images/png/orange.png")
      |> loadImageFromBuffer;
    let img2 =
      TestUtils.getFileContents("test/test-images/png/orange_changed.png")
      |> loadImageFromBuffer;

    let (_, diffPixels, diffPercentage) = Diff.compare(img1, img2, ());

    expect.int(diffPixels).toBe(1430);
    expect.float(diffPercentage).toBeCloseTo(1.20);
  });
});
