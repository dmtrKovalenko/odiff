open Alcotest
module Diff = Odiff.Diff.MakeDiff (Png.IO) (Png.IO)

let load_image path =
  match Png.IO.loadImage path with
  | exception ex ->
      fail
        (Printf.sprintf "Failed to load image: %s\nError: %s" path
           (Printexc.to_string ex))
  | img -> img

let () =
  run "IO"
    [
      ( "PNG",
        [
          test_case "finds difference between 2 images" `Quick (fun () ->
              let img1 = load_image "test-images/png/orange.png" in
              let img2 = load_image "test-images/png/orange_changed.png" in
              let _, diffPixels, diffPercentage, _, _ =
                Diff.compare img1 img2 ()
              in
              check int "diffPixels" 1366 diffPixels;
              check (float 0.1) "diffPercentage" 1.14 diffPercentage);
          test_case "Diff of mask and no mask are equal" `Quick (fun () ->
              let img1 = load_image "test-images/png/orange.png" in
              let img2 = load_image "test-images/png/orange_changed.png" in
              let _, diffPixels, diffPercentage, _, _ =
                Diff.compare img1 img2 ~outputDiffMask:false ()
              in
              let img1 = load_image "test-images/png/orange.png" in
              let img2 = load_image "test-images/png/orange_changed.png" in
              let _, diffPixelsMask, diffPercentageMask, _, _ =
                Diff.compare img1 img2 ~outputDiffMask:true ()
              in
              check int "diffPixels" diffPixels diffPixelsMask;
              check (float 0.001) "diffPercentage" diffPercentage
                diffPercentageMask);
          test_case "Creates correct diff output image" `Quick (fun () ->
              let img1 = load_image "test-images/png/orange.png" in
              let img2 = load_image "test-images/png/orange_changed.png" in
              let diffOutput, _, _, _, _ = Diff.compare img1 img2 () in
              check bool "diffOutput" (Option.is_some diffOutput) true;
              let diffOutput = Option.get diffOutput in
              let originalDiff = load_image "test-images/png/orange_diff.png" in
              let diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _, _ =
                Diff.compare originalDiff diffOutput ()
              in
              check bool "diffMaskOfDiff" (Option.is_some diffMaskOfDiff) true;
              let diffMaskOfDiff = Option.get diffMaskOfDiff in
              if diffOfDiffPixels > 0 then (
                Png.IO.saveImage diffOutput "test-images/png/diff-output.png";
                Png.IO.saveImage diffMaskOfDiff
                  "test-images/png/diff-of-diff.png");
              check int "diffOfDiffPixels" 0 diffOfDiffPixels;
              check (float 0.001) "diffOfDiffPercentage" 0.0
                diffOfDiffPercentage);
          test_case "Correctly handles different encodings of transparency"
            `Quick (fun () ->
              let img1 = load_image "test-images/png/extreme-alpha.png" in
              let img2 = load_image "test-images/png/extreme-alpha-1.png" in
              let _, diffPixels, _, _, _ = Diff.compare img1 img2 () in
              check int "diffPixels" 0 diffPixels);
        ] );
    ]
