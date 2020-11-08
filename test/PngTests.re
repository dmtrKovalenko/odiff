open TestFramework;

describe("Png comparing", ({test, _}) => {
  test("finds different between 2 images", ({expect, _}) => {
    let img1 = Odiff.ImageIO.loadImage("test/test-images/orange.png");
    let img2 = Odiff.ImageIO.loadImage("test/test-images/orange_changed.png");

    let diffOutput = Rgba32.copy(img1);

    let diffPixels = Odiff.Diff.compare(img1, img2, diffOutput, ());
    expect.int(diffPixels).toBe(1430);
  });

  test("uses provided threshold", ({expect, _}) => {
    let img1 = Odiff.ImageIO.loadImage("test/test-images/orange.png");
    let img2 = Odiff.ImageIO.loadImage("test/test-images/orange_changed.png");

    let diffOutput = Rgba32.copy(img1);

    let diffPixels =
      Odiff.Diff.compare(img1, img2, diffOutput, ~threshold=1.0, ());
    expect.int(diffPixels).toBe(184);
  });

  test("create right diff mask", ({expect, _}) => {
    let img1 = Odiff.ImageIO.loadImage("test/test-images/orange.png");
    let img2 = Odiff.ImageIO.loadImage("test/test-images/orange_changed.png");

    let diffOutput = Rgba32.create(img1.width, img1.height);
    Odiff.Diff.compare(img1, img2, diffOutput, ()) |> ignore;

    let originalDiff =
      Odiff.ImageIO.loadImage("test/test-images/orange-diff.png");
    let diffMaskOfDiff =
      Rgba32.create(originalDiff.width, originalDiff.height);

    let diffOfDiffPixels =
      Odiff.Diff.compare(originalDiff, diffOutput, diffMaskOfDiff, ());

    expect.int(diffOfDiffPixels).toBe(0);
  });
});