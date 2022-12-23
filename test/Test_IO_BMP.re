open TestFramework;
open ODiffIO;

module Diff = Odiff.Diff.MakeDiff(Bmp.IO, Bmp.IO);
module Output_Diff = Odiff.Diff.MakeDiff(Png.IO, Bmp.IO);

describe("IO: BMP", ({test, _}) => {
  test("finds difference between 2 images", ({expect, _}) => {
    let img1 = Bmp.IO.loadImageFromPath("test/test-images/bmp/clouds.bmp");
    let img2 = Bmp.IO.loadImageFromPath("test/test-images/bmp/clouds-2.bmp");

    let (_, diffPixels, diffPercentage) = Diff.compare(img1, img2, ());

    expect.int(diffPixels).toBe(191);
    expect.float(diffPercentage).toBeCloseTo(0.076);
  });

  test("Diff of mask and no mask are equal", ({expect, _}) => {
    let img1 = Bmp.IO.loadImageFromPath("test/test-images/bmp/clouds.bmp");
    let img2 = Bmp.IO.loadImageFromPath("test/test-images/bmp/clouds-2.bmp");

    let (_, diffPixels, diffPercentage) =
      Diff.compare(img1, img2, ~outputDiffMask=false, ());

    let img1 = Bmp.IO.loadImageFromPath("test/test-images/bmp/clouds.bmp");
    let img2 = Bmp.IO.loadImageFromPath("test/test-images/bmp/clouds-2.bmp");

    let (_, diffPixelsMask, diffPercentageMask) =
      Diff.compare(img1, img2, ~outputDiffMask=true, ());

    expect.int(diffPixels).toBe(diffPixelsMask);
    expect.float(diffPercentage).toBeCloseTo(diffPercentageMask);
  });

  test("Creates correct diff output image", ({expect, _}) => {
    let img1 = Bmp.IO.loadImageFromPath("test/test-images/bmp/clouds.bmp");
    let img2 = Bmp.IO.loadImageFromPath("test/test-images/bmp/clouds-2.bmp");

    let (diffOutput, _, _) = Diff.compare(img1, img2, ());

    let originalDiff =
      Png.IO.loadImageFromPath("test/test-images/bmp/clouds-diff.png");
    let (diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage) =
      Output_Diff.compare(originalDiff, diffOutput, ());

    if (diffOfDiffPixels > 0) {
      Bmp.IO.saveImage(diffOutput, "test/test-images/bmp/_diff-output.png");
      Png.IO.saveImage(
        diffMaskOfDiff,
        "test/test-images/bmp/_diff-of-diff.png",
      );
    };

    expect.int(diffOfDiffPixels).toBe(0);
    expect.float(diffOfDiffPercentage).toBeCloseTo(0.0);
  });

  test("Can load images with a provided buffer", ({expect, _}) => {
    let img1 =
      TestUtils.getFileContents("test/test-images/bmp/clouds.bmp")
      |> Bmp.IO.loadImageFromBuffer;
    let img2 =
      TestUtils.getFileContents("test/test-images/bmp/clouds-2.bmp")
      |> Bmp.IO.loadImageFromBuffer;

    let (_, diffPixels, diffPercentage) = Diff.compare(img1, img2, ());

    expect.int(diffPixels).toBe(191);
    expect.float(diffPercentage).toBeCloseTo(0.076);
  });
});
