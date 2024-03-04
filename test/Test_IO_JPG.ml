open TestFramework
open ODiffIO
module Diff = Odiff.Diff.MakeDiff (Jpg.IO) (Jpg.IO)
module Output_Diff = Odiff.Diff.MakeDiff (Png.IO) (Jpg.IO)

let _ =
  describe "IO: JPG / JPEG" (fun { test; _ } ->
      test "finds difference between 2 images" (fun { expect; _ } ->
          let img1 = Jpg.IO.loadImage "test/test-images/jpg/tiger.jpg" in
          let img2 = Jpg.IO.loadImage "test/test-images/jpg/tiger-2.jpg" in
          let _, diffPixels, diffPercentage, _ = Diff.compare img1 img2 () in
          (expect.int diffPixels).toBe 7586;
          (expect.float diffPercentage).toBeCloseTo 1.14);
      test "Diff of mask and no mask are equal" (fun { expect; _ } ->
          let img1 = Jpg.IO.loadImage "test/test-images/jpg/tiger.jpg" in
          let img2 = Jpg.IO.loadImage "test/test-images/jpg/tiger-2.jpg" in
          let _, diffPixels, diffPercentage, _ =
            Diff.compare img1 img2 ~outputDiffMask:false ()
          in
          let img1 = Jpg.IO.loadImage "test/test-images/jpg/tiger.jpg" in
          let img2 = Jpg.IO.loadImage "test/test-images/jpg/tiger-2.jpg" in
          let _, diffPixelsMask, diffPercentageMask, _ =
            Diff.compare img1 img2 ~outputDiffMask:true ()
          in
          (expect.int diffPixels).toBe diffPixelsMask;
          (expect.float diffPercentage).toBeCloseTo diffPercentageMask);
      test "Creates correct diff output image" (fun { expect; _ } ->
          let img1 = Jpg.IO.loadImage "test/test-images/jpg/tiger.jpg" in
          let img2 = Jpg.IO.loadImage "test/test-images/jpg/tiger-2.jpg" in
          let diffOutput, _, _, _ = Diff.compare img1 img2 () in
          let originalDiff =
            Png.IO.loadImage "test/test-images/jpg/tiger-diff.png"
          in
          let diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _ =
            Output_Diff.compare originalDiff diffOutput ()
          in
          if diffOfDiffPixels > 0 then (
            Jpg.IO.saveImage diffOutput "test/test-images/jpg/_diff-output.png";
            Png.IO.saveImage diffMaskOfDiff
              "test/test-images/jpg/_diff-of-diff.png");
          (expect.int diffOfDiffPixels).toBe 0;
          (expect.float diffOfDiffPercentage).toBeCloseTo 0.0))
