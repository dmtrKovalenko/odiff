open TestFramework;
open ODiffIO;

module Diff = Odiff.Diff.MakeDiff(Tiff.IO, Tiff.IO);
module Output_Diff = Odiff.Diff.MakeDiff(Png.IO, Tiff.IO);

describe("IO: TIFF", ({test, _}) => {
  test("finds difference between 2 images", ({expect, _}) => {
    let img1 = Tiff.IO.loadImage("test/test-images/tiff/laptops.tiff");
    let img2 = Tiff.IO.loadImage("test/test-images/tiff/laptops-2.tiff");

    let (_, diffPixels, diffPercentage) = Diff.compare(img1, img2, ());

    expect.int(diffPixels).toBe(8569);
    expect.float(diffPercentage).toBeCloseTo(3.79);
  });

  test("Diff of mask and no mask are equal", ({expect, _}) => {
    let img1 = Tiff.IO.loadImage("test/test-images/tiff/laptops.tiff");
    let img2 = Tiff.IO.loadImage("test/test-images/tiff/laptops-2.tiff");

    let (_, diffPixels, diffPercentage) =
      Diff.compare(img1, img2, ~outputDiffMask=false, ());

    let img1 = Tiff.IO.loadImage("test/test-images/tiff/laptops.tiff");
    let img2 = Tiff.IO.loadImage("test/test-images/tiff/laptops-2.tiff");

    let (_, diffPixelsMask, diffPercentageMask) =
      Diff.compare(img1, img2, ~outputDiffMask=true, ());

    expect.int(diffPixels).toBe(diffPixelsMask);
    expect.float(diffPercentage).toBeCloseTo(diffPercentageMask);
  });

  test("Creates correct diff output image", ({expect, _}) => {
    let img1 = Tiff.IO.loadImage("test/test-images/tiff/laptops.tiff");
    let img2 = Tiff.IO.loadImage("test/test-images/tiff/laptops-2.tiff");

    let (diffOutput, _, _) = Diff.compare(img1, img2, ());

    let originalDiff =
      Png.IO.loadImage("test/test-images/tiff/laptops-diff.png");
    let (diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage) =
      Output_Diff.compare(originalDiff, diffOutput, ());

    if (diffOfDiffPixels > 0) {
      Tiff.IO.saveImage(diffOutput, "test/test-images/tiff/_diff-output.png");
      Png.IO.saveImage(
        diffMaskOfDiff,
        "test/test-images/tiff/_diff-of-diff.png",
      );
    };

    expect.int(diffOfDiffPixels).toBe(0);
    expect.float(diffOfDiffPercentage).toBeCloseTo(0.0);
  });
});
