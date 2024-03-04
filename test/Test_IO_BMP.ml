open TestFramework
open ODiffIO
module Diff = Odiff.Diff.MakeDiff (Bmp.IO) (Bmp.IO)
module Output_Diff = Odiff.Diff.MakeDiff (Png.IO) (Bmp.IO)

let _ =
  describe "IO: BMP" (fun { test; _ } ->
      test "finds difference between 2 images" (fun { expect; _ } ->
          let img1 = Bmp.IO.loadImage "test/test-images/bmp/clouds.bmp" in
          let img2 = Bmp.IO.loadImage "test/test-images/bmp/clouds-2.bmp" in
          let _, diffPixels, diffPercentage, _ = Diff.compare img1 img2 () in
          (expect.int diffPixels).toBe 191;
          (expect.float diffPercentage).toBeCloseTo 0.076);
      test "Diff of mask and no mask are equal" (fun { expect; _ } ->
          let img1 = Bmp.IO.loadImage "test/test-images/bmp/clouds.bmp" in
          let img2 = Bmp.IO.loadImage "test/test-images/bmp/clouds-2.bmp" in
          let _, diffPixels, diffPercentage, _ =
            Diff.compare img1 img2 ~outputDiffMask:false ()
          in
          let img1 = Bmp.IO.loadImage "test/test-images/bmp/clouds.bmp" in
          let img2 = Bmp.IO.loadImage "test/test-images/bmp/clouds-2.bmp" in
          let _, diffPixelsMask, diffPercentageMask, _ =
            Diff.compare img1 img2 ~outputDiffMask:true ()
          in
          (expect.int diffPixels).toBe diffPixelsMask;
          (expect.float diffPercentage).toBeCloseTo diffPercentageMask);
      test "Creates correct diff output image" (fun { expect; _ } ->
          let img1 = Bmp.IO.loadImage "test/test-images/bmp/clouds.bmp" in
          let img2 = Bmp.IO.loadImage "test/test-images/bmp/clouds-2.bmp" in
          let diffOutput, _, _, _ = Diff.compare img1 img2 () in
          let originalDiff =
            Png.IO.loadImage "test/test-images/bmp/clouds-diff.png"
          in
          let diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _ =
            Output_Diff.compare originalDiff diffOutput ()
          in
          if diffOfDiffPixels > 0 then (
            Bmp.IO.saveImage diffOutput "test/test-images/bmp/_diff-output.png";
            Png.IO.saveImage diffMaskOfDiff
              "test/test-images/bmp/_diff-of-diff.png");
          (expect.int diffOfDiffPixels).toBe 0;
          (expect.float diffOfDiffPercentage).toBeCloseTo 0.0))
