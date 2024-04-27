open TestFramework
open ODiffIO
module Diff = Odiff.Diff.MakeDiff (Png.IO) (Png.IO)

let _ =
  describe "IO: PNG" (fun { test; _ } ->
      let open Png.IO in
      test "finds difference between 2 images" (fun { expect; _ } ->
          let img1 = loadImage "test/test-images/png/orange.png" in
          let img2 = loadImage "test/test-images/png/orange_changed.png" in
          let _, diffPixels, diffPercentage, _ = Diff.compare img1 img2 () in
          (expect.int diffPixels).toBe 1366;
          (expect.float diffPercentage).toBeCloseTo 1.14);
      test "Diff of mask and no mask are equal" (fun { expect; _ } ->
          let img1 = loadImage "test/test-images/png/orange.png" in
          let img2 = loadImage "test/test-images/png/orange_changed.png" in
          let _, diffPixels, diffPercentage, _ =
            Diff.compare img1 img2 ~outputDiffMask:false ()
          in
          let img1 = loadImage "test/test-images/png/orange.png" in
          let img2 = loadImage "test/test-images/png/orange_changed.png" in
          let _, diffPixelsMask, diffPercentageMask, _ =
            Diff.compare img1 img2 ~outputDiffMask:true ()
          in
          (expect.int diffPixels).toBe diffPixelsMask;
          (expect.float diffPercentage).toBeCloseTo diffPercentageMask);
      test "Creates correct diff output image" (fun { expect; _ } ->
          let img1 = loadImage "test/test-images/png/orange.png" in
          let img2 = loadImage "test/test-images/png/orange_changed.png" in
          let diffOutput, _, _, _ = Diff.compare img1 img2 () in
          let originalDiff = loadImage "test/test-images/png/orange_diff.png" in
          let diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _ =
            Diff.compare originalDiff diffOutput ()
          in
          if diffOfDiffPixels > 0 then (
            saveImage diffOutput "test/test-images/png/diff-output.png";
            saveImage diffMaskOfDiff "test/test-images/png/diff-of-diff.png");
          (expect.int diffOfDiffPixels).toBe 0;
          (expect.float diffOfDiffPercentage).toBeCloseTo 0.0))
