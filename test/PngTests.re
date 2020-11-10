open TestFramework;

describe("Png comparing", ({test, _}) => {
  test("finds different between 2 images", ({expect, _}) => {
    let img1 = Odiff.ImageIO.loadImage("test/test-images/orange.png");
    let img2 = Odiff.ImageIO.loadImage("test/test-images/orange_changed.png");

    let (_, diffPixels) = Odiff.Diff.compare(img1, img2, ());
    expect.int(diffPixels).toBe(1430);
  });

  test("uses provided threshold", ({expect, _}) => {
    let img1 = Odiff.ImageIO.loadImage("test/test-images/orange.png");
    let img2 = Odiff.ImageIO.loadImage("test/test-images/orange_changed.png");

    let (_, diffPixels) = Odiff.Diff.compare(img1, img2, ~threshold=0.5, ());
    expect.int(diffPixels).toBe(222);
  });

  test("creates the right diff output image", ({expect, _}) => {
    let img1 = Odiff.ImageIO.loadImage("test/test-images/orange.png");
    let img2 = Odiff.ImageIO.loadImage("test/test-images/orange_changed.png");

    let (diffOutput, _) = Odiff.Diff.compare(img1, img2, ());

    let originalDiff =
      Odiff.ImageIO.loadImage("test/test-images/orange_diff.png");
    let (diffMaskOfDiff, diffOfDiffPixels) =
      Odiff.Diff.compare(originalDiff, diffOutput, ());

    if (diffOfDiffPixels > 0) {
      diffOutput
      |> Odiff.ImageIO.saveImage("test/test-images/diff-output.png");
      diffMaskOfDiff
      |> Odiff.ImageIO.saveImage("test/test-images/diff-of-diff.png");
    };

    expect.int(diffOfDiffPixels).toBe(0);
  });
});