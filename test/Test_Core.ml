open TestFramework
open ODiffIO
module PNG_Diff = Odiff.Diff.MakeDiff (Png.IO) (Png.IO)

let _ =
  describe "CORE: Antialiasing" (fun { test; _ } ->
      let open Png.IO in
      test "does not count anti-aliased pixels as different"
        (fun { expect; _ } ->
          let img1 = loadImage "test/test-images/aa/antialiasing-on.png" in
          let img2 = loadImage "test/test-images/aa/antialiasing-off.png" in
          let _, diffPixels, diffPercentage, _ =
            PNG_Diff.compare img1 img2 ~outputDiffMask:false ~antialiasing:true
              ()
          in
          (expect.int diffPixels).toBe 46;
          (expect.float diffPercentage).toBeCloseTo 0.115);
      test "tests different sized AA images" (fun { expect; _ } ->
          let img1 = loadImage "test/test-images/aa/antialiasing-on.png" in
          let img2 =
            loadImage "test/test-images/aa/antialiasing-off-small.png"
          in
          let _, diffPixels, diffPercentage, _ =
            PNG_Diff.compare img1 img2 ~outputDiffMask:true ~antialiasing:true
              ()
          in
          (expect.int diffPixels).toBe 417;
          (expect.float diffPercentage).toBeCloseTo 1.04))

let _ =
  describe "CORE: Threshold" (fun { test; _ } ->
      test "uses provided threshold" (fun { expect; _ } ->
          let img1 = Png.IO.loadImage "test/test-images/png/orange.png" in
          let img2 =
            Png.IO.loadImage "test/test-images/png/orange_changed.png"
          in
          let _, diffPixels, diffPercentage, _ =
            PNG_Diff.compare img1 img2 ~threshold:0.5 ()
          in
          (expect.int diffPixels).toBe 25;
          (expect.float diffPercentage).toBeCloseTo 0.02))

let _ =
  describe "CORE: Ignore Regions" (fun { test; _ } ->
      test "uses provided irgnore regions" (fun { expect; _ } ->
          let img1 = Png.IO.loadImage "test/test-images/png/orange.png" in
          let img2 =
            Png.IO.loadImage "test/test-images/png/orange_changed.png"
          in
          let _diffOutput, diffPixels, diffPercentage, _ =
            PNG_Diff.compare img1 img2
              ~ignoreRegions:
                [ ((150, 30), (310, 105)); ((20, 175), (105, 200)) ]
              ()
          in
          (expect.int diffPixels).toBe 0;
          (expect.float diffPercentage).toBeCloseTo 0.0))

let _ =
  describe "CORE: Diff Color" (fun { test; _ } ->
      test "creates diff output image with custom green diff color"
        (fun { expect; _ } ->
          let img1 = Png.IO.loadImage "test/test-images/png/orange.png" in
          let img2 =
            Png.IO.loadImage "test/test-images/png/orange_changed.png"
          in
          let diffOutput, _, _, _ =
            PNG_Diff.compare img1 img2
              ~diffPixel:
                (Int32.of_int 4278255360 (*int32 representation of #00ff00*))
              ()
          in
          let originalDiff =
            Png.IO.loadImage "test/test-images/png/orange_diff_green.png"
          in
          let diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _ =
            PNG_Diff.compare originalDiff diffOutput ()
          in
          if diffOfDiffPixels > 0 then (
            Png.IO.saveImage diffOutput
              "test/test-images/png/diff-output-green.png";
            Png.IO.saveImage diffMaskOfDiff
              "test/test-images/png/diff-of-diff-green.png");
          (expect.int diffOfDiffPixels).toBe 0;
          (expect.float diffOfDiffPercentage).toBeCloseTo 0.0))

let _ =
  describe "CORE: blendSemiTransparentColor" (fun { test; _ } ->
      test "blend 255. alpha" (fun { expect; _ } ->
          let r, g, b, a =
            Odiff.ColorDelta.blendSemiTransparentColor (0., 128., 255., 255.)
          in
          (expect.float r).toBeCloseTo 0.;
          (expect.float g).toBeCloseTo 128.;
          (expect.float b).toBeCloseTo 255.;
          (expect.float a).toBeCloseTo 1.);

      test "blend 0. alpha" (fun { expect; _ } ->
          let r, g, b, a =
            Odiff.ColorDelta.blendSemiTransparentColor (0., 128., 255., 0.)
          in
          (expect.float r).toBeCloseTo 255.;
          (expect.float g).toBeCloseTo 255.;
          (expect.float b).toBeCloseTo 255.;
          (expect.float a).toBeCloseTo 0.);

      test "blend 5. alpha" (fun { expect; _ } ->
          let r, g, b, a =
            Odiff.ColorDelta.blendSemiTransparentColor (0., 128., 255., 5.)
          in
          (expect.float r).toBeCloseTo 250.;
          (expect.float g).toBeCloseTo 252.51;
          (expect.float b).toBeCloseTo 255.;
          (expect.float a).toBeCloseTo 0.02);

      test "blend 51. alpha" (fun { expect; _ } ->
          let r, g, b, a =
            Odiff.ColorDelta.blendSemiTransparentColor (0., 128., 255., 51.)
          in
          (expect.float r).toBeCloseTo 204.;
          (expect.float g).toBeCloseTo 229.6;
          (expect.float b).toBeCloseTo 255.;
          (expect.float a).toBeCloseTo 0.2);

      test "blend 128. alpha" (fun { expect; _ } ->
          let r, g, b, a =
            Odiff.ColorDelta.blendSemiTransparentColor (0., 128., 255., 128.)
          in
          (expect.float r).toBeCloseTo 127.;
          (expect.float g).toBeCloseTo 191.25;
          (expect.float b).toBeCloseTo 255.;
          (expect.float a).toBeCloseTo 0.5))
