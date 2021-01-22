open TestFramework;
open ODiffIO;

module Diff = Odiff.Diff.MakeDiff(PureC_IO.IO, PureC_IO.IO);

describe("Png comparing", ({test, _}) => {
  test("finds different between 2 images", ({expect, _}) => {
    let img1 = PureC_IO.IO.loadImage("test/test-images/orange.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/orange_changed.png");

    let (_, diffPixels) = Diff.compare(img1, img2, ());
    expect.int(diffPixels).toBe(1430);
  });

  test("uses provided threshold", ({expect, _}) => {
    let img1 = PureC_IO.IO.loadImage("test/test-images/orange.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/orange_changed.png");

    let (_, diffPixels) = Diff.compare(img1, img2, ~threshold=0.5, ());
    expect.int(diffPixels).toBe(222);
  });

  test("creates the right diff output image", ({expect, _}) => {
    let img1 = PureC_IO.IO.loadImage("test/test-images/orange.png");
    let img2 = PureC_IO.IO.loadImage("test/test-images/orange_changed.png");

    let (diffOutput, _) = Diff.compare(img1, img2, ());

    let originalDiff =
      PureC_IO.IO.loadImage("test/test-images/orange_diff.png");
    let (diffMaskOfDiff, diffOfDiffPixels) =
      Diff.compare(originalDiff, diffOutput, ());

    if (diffOfDiffPixels > 0) {
      PureC_IO.IO.saveImage(diffOutput, "test/test-images/diff-output.png");
      PureC_IO.IO.saveImage(diffMaskOfDiff, "test/test-images/diff-of-diff.png");
    };

    expect.int(diffOfDiffPixels).toBe(0);
  });
});