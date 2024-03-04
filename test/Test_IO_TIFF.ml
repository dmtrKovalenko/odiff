open TestFramework
open ODiffIO
module Diff = Odiff.Diff.MakeDiff (Tiff.IO) (Tiff.IO)
module Output_Diff = Odiff.Diff.MakeDiff (Png.IO) (Tiff.IO)

let _ =
  describe "IO: TIFF" (fun { test; _ } ->
      test "finds difference between 2 images" (fun { expect; _ } ->
          let img1 = Tiff.IO.loadImage "test/test-images/tiff/laptops.tiff" in
          let img2 = Tiff.IO.loadImage "test/test-images/tiff/laptops-2.tiff" in
          let _, diffPixels, diffPercentage, _ = Diff.compare img1 img2 () in
          (expect.int diffPixels).toBe 8569;
          (expect.float diffPercentage).toBeCloseTo 3.79);

      test "Diff of mask and no mask are equal" (fun { expect; _ } ->
          let img1 = Tiff.IO.loadImage "test/test-images/tiff/laptops.tiff" in
          let img2 = Tiff.IO.loadImage "test/test-images/tiff/laptops-2.tiff" in
          let _, diffPixels, diffPercentage, _ =
            Diff.compare img1 img2 ~outputDiffMask:false ()
          in
          let img1 = Tiff.IO.loadImage "test/test-images/tiff/laptops.tiff" in
          let img2 = Tiff.IO.loadImage "test/test-images/tiff/laptops-2.tiff" in
          let _, diffPixelsMask, diffPercentageMask, _ =
            Diff.compare img1 img2 ~outputDiffMask:true ()
          in
          (expect.int diffPixels).toBe diffPixelsMask;
          (expect.float diffPercentage).toBeCloseTo diffPercentageMask);
      test "Creates correct diff output image" (fun { expect; _ } ->
          let img1 = Tiff.IO.loadImage "test/test-images/tiff/laptops.tiff" in
          let img2 = Tiff.IO.loadImage "test/test-images/tiff/laptops-2.tiff" in
          let diffOutput, _, _, _ = Diff.compare img1 img2 () in
          let originalDiff =
            Png.IO.loadImage "test/test-images/tiff/laptops-diff.png"
          in
          let diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _ =
            Output_Diff.compare originalDiff diffOutput ()
          in
          if diffOfDiffPixels > 0 then (
            Tiff.IO.saveImage diffOutput
              "test/test-images/tiff/_diff-output.png";
            Png.IO.saveImage diffMaskOfDiff
              "test/test-images/tiff/_diff-of-diff.png");
          (expect.int diffOfDiffPixels).toBe 0;
          (expect.float diffOfDiffPercentage).toBeCloseTo 0.0))
