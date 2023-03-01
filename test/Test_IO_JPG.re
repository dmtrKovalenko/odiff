open TestFramework;
open ODiffIO;

module Diff = Odiff.Diff.MakeDiff(Jpg.IO, Jpg.IO);
module Output_Diff = Odiff.Diff.MakeDiff(Png.IO, Jpg.IO);

describe("IO: JPG / JPEG", ({test, _}) => {
  test("finds difference between 2 images", ({expect, _}) => {
    let img1 = Jpg.IO.loadImage("test/test-images/jpg/tiger.jpg");
    let img2 = Jpg.IO.loadImage("test/test-images/jpg/tiger-2.jpg");

    let (_, diffPixels, diffPercentage, _) = Diff.compare(img1, img2, ());

    expect.int(diffPixels).toBe(7586);
    expect.float(diffPercentage).toBeCloseTo(1.14);
  });

  test("Diff of mask and no mask are equal", ({expect, _}) => {
    let img1 = Jpg.IO.loadImage("test/test-images/jpg/tiger.jpg");
    let img2 = Jpg.IO.loadImage("test/test-images/jpg/tiger-2.jpg");

    let (_, diffPixels, diffPercentage, _) =
      Diff.compare(img1, img2, ~outputDiffMask=false, ());

    let img1 = Jpg.IO.loadImage("test/test-images/jpg/tiger.jpg");
    let img2 = Jpg.IO.loadImage("test/test-images/jpg/tiger-2.jpg");

    let (_, diffPixelsMask, diffPercentageMask, _) =
      Diff.compare(img1, img2, ~outputDiffMask=true, ());

    expect.int(diffPixels).toBe(diffPixelsMask);
    expect.float(diffPercentage).toBeCloseTo(diffPercentageMask);
  });

  test("Creates correct diff output image", ({expect, _}) => {
    let img1 = Jpg.IO.loadImage("test/test-images/jpg/tiger.jpg");
    let img2 = Jpg.IO.loadImage("test/test-images/jpg/tiger-2.jpg");

    let (diffOutput, _, _, _) = Diff.compare(img1, img2, ());

    let originalDiff =
      Png.IO.loadImage("test/test-images/jpg/tiger-diff.png");
    let (diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _) =
      Output_Diff.compare(originalDiff, diffOutput, ());

    if (diffOfDiffPixels > 0) {
      Jpg.IO.saveImage(diffOutput, "test/test-images/jpg/_diff-output.png");
      Png.IO.saveImage(
        diffMaskOfDiff,
        "test/test-images/jpg/_diff-of-diff.png",
      );
    };

    expect.int(diffOfDiffPixels).toBe(0);
    expect.float(diffOfDiffPercentage).toBeCloseTo(0.0);
  });
});
