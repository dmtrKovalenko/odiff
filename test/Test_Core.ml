open Alcotest
module PNG_Diff = Odiff.Diff.MakeDiff (Png.IO) (Png.IO)

let test_antialiasing () =
  Sys.getcwd () |> print_endline;
  let img1 = Png.IO.loadImage "test-images/aa/antialiasing-on.png" in
  let img2 = Png.IO.loadImage "test-images/aa/antialiasing-off.png" in
  let _, diffPixels, diffPercentage, _ =
    PNG_Diff.compare img1 img2 ~outputDiffMask:false ~antialiasing:true ()
  in
  check int "diffPixels" 46 diffPixels;
  check (float 0.001) "diffPercentage" 0.115 diffPercentage

let test_different_sized_aa_images () =
  let img1 = Png.IO.loadImage "test-images/aa/antialiasing-on.png" in
  let img2 = Png.IO.loadImage "test-images/aa/antialiasing-off-small.png" in
  let _, diffPixels, diffPercentage, _ =
    PNG_Diff.compare img1 img2 ~outputDiffMask:true ~antialiasing:true ()
  in
  check int "diffPixels" 417 diffPixels;
  check (float 0.01) "diffPercentage" 1.0425 diffPercentage

let test_threshold () =
  let img1 = Png.IO.loadImage "test-images/png/orange.png" in
  let img2 = Png.IO.loadImage "test-images/png/orange_changed.png" in
  let _, diffPixels, diffPercentage, _ =
    PNG_Diff.compare img1 img2 ~threshold:0.5 ()
  in
  check int "diffPixels" 25 diffPixels;
  check (float 0.001) "diffPercentage" 0.02 diffPercentage

let test_ignore_regions () =
  let img1 = Png.IO.loadImage "test-images/png/orange.png" in
  let img2 = Png.IO.loadImage "test-images/png/orange_changed.png" in
  let _diffOutput, diffPixels, diffPercentage, _ =
    PNG_Diff.compare img1 img2
      ~ignoreRegions:[ ((150, 30), (310, 105)); ((20, 175), (105, 200)) ]
      ()
  in
  check int "diffPixels" 0 diffPixels;
  check (float 0.001) "diffPercentage" 0.0 diffPercentage

let test_diff_color () =
  let img1 = Png.IO.loadImage "test-images/png/orange.png" in
  let img2 = Png.IO.loadImage "test-images/png/orange_changed.png" in
  let diffOutput, _, _, _ =
    PNG_Diff.compare img1 img2
      ~diffPixel:(Int32.of_int 4278255360 (*int32 representation of #00ff00*))
      ()
  in
  check bool "diffOutput" (Option.is_some diffOutput) true;
  let diffOutput = Option.get diffOutput in
  let originalDiff = Png.IO.loadImage "test-images/png/orange_diff_green.png" in
  let diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _ =
    PNG_Diff.compare originalDiff diffOutput ()
  in
  check bool "diffMaskOfDiff" (Option.is_some diffMaskOfDiff) true;
  let diffMaskOfDiff = Option.get diffMaskOfDiff in
  if diffOfDiffPixels > 0 then (
    Png.IO.saveImage diffOutput "test-images/png/diff-output-green.png";
    Png.IO.saveImage diffMaskOfDiff "test-images/png/diff-of-diff-green.png");
  check int "diffOfDiffPixels" 0 diffOfDiffPixels;
  check (float 0.001) "diffOfDiffPercentage" 0.0 diffOfDiffPercentage

let test_blend_semi_transparent_color () =
  let open Odiff.ColorDelta in
  let test_blend r g b a expected_r expected_g expected_b expected_a =
    let { r; g; b; a } = blendSemiTransparentPixel { r; g; b; a } in
    check (float 0.01) "r" expected_r r;
    check (float 0.01) "g" expected_g g;
    check (float 0.01) "b" expected_b b;
    check (float 0.01) "a" expected_a a
  in
  test_blend 0. 128. 255. 255. 0. 128. 255. 1.;
  test_blend 0. 128. 255. 0. 255. 255. 255. 0.;
  test_blend 0. 128. 255. 5. 250. 252.51 255. 0.02;
  test_blend 0. 128. 255. 51. 204. 229.6 255. 0.2;
  test_blend 0. 128. 255. 128. 127. 191.25 255. 0.5

let test_different_layouts () =
  Sys.getcwd () |> print_endline;
  let img1 = Png.IO.loadImage "test-images/png/white4x4.png" in
  let img2 = Png.IO.loadImage "test-images/png/purple8x8.png" in
  let _, diffPixels, diffPercentage, _ =
    PNG_Diff.compare img1 img2 ~outputDiffMask:false ~antialiasing:false ()
  in
  check int "diffPixels" 16 diffPixels;
  check (float 0.001) "diffPercentage" 100.0 diffPercentage

let () =
  run "CORE"
    [
      ( "Antialiasing",
        [
          test_case "does not count anti-aliased pixels as different" `Quick
            test_antialiasing;
          test_case "tests different sized AA images" `Quick
            test_different_sized_aa_images;
        ] );
      ( "Threshold",
        [ test_case "uses provided threshold" `Quick test_threshold ] );
      ( "Ignore Regions",
        [ test_case "uses provided ignore regions" `Quick test_ignore_regions ]
      );
      ( "Diff Color",
        [
          test_case "creates diff output image with custom green diff color"
            `Quick test_diff_color;
        ] );
      ( "blendSemiTransparentColor",
        [
          test_case "blend semi-transparent colors" `Quick
            test_blend_semi_transparent_color;
        ] );
      ( "layoutDifference",
        [
          test_case "diff images with different layouts" `Quick
            test_different_layouts;
        ] );
    ]
