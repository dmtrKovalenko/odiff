open Alcotest
module Diff = Odiff.Diff.MakeDiff (Tiff.IO) (Tiff.IO)
module Output_Diff = Odiff.Diff.MakeDiff (Png.IO) (Tiff.IO)

let load_tiff_image path =
  match Tiff.IO.loadImage path with
  | exception ex ->
      fail
        (Printf.sprintf "Failed to load image: %s\nError: %s" path
           (Printexc.to_string ex))
  | img -> img

let load_png_image path =
  match Png.IO.loadImage path with
  | exception ex ->
      fail
        (Printf.sprintf "Failed to load image: %s\nError: %s" path
           (Printexc.to_string ex))
  | img -> img

let run_tiff_tests () =
  run "IO"
    [
      ( "TIFF",
        [
          test_case "finds difference between 2 images" `Quick (fun () ->
              let img1 = load_tiff_image "test-images/tiff/laptops.tiff" in
              let img2 = load_tiff_image "test-images/tiff/laptops-2.tiff" in
              let _, diffPixels, diffPercentage, _ =
                Diff.compare img1 img2 ()
              in
              check int "diffPixels" 8569 diffPixels;
              check (float 0.01) "diffPercentage" 3.79 diffPercentage);
          test_case "Diff of mask and no mask are equal" `Quick (fun () ->
              let img1 = load_tiff_image "test-images/tiff/laptops.tiff" in
              let img2 = load_tiff_image "test-images/tiff/laptops-2.tiff" in
              let _, diffPixels, diffPercentage, _ =
                Diff.compare img1 img2 ~outputDiffMask:false ()
              in
              let img1 = load_tiff_image "test-images/tiff/laptops.tiff" in
              let img2 = load_tiff_image "test-images/tiff/laptops-2.tiff" in
              let _, diffPixelsMask, diffPercentageMask, _ =
                Diff.compare img1 img2 ~outputDiffMask:true ()
              in
              check int "diffPixels" diffPixels diffPixelsMask;
              check (float 0.001) "diffPercentage" diffPercentage
                diffPercentageMask);
          test_case "Creates correct diff output image" `Quick (fun () ->
              let img1 = load_tiff_image "test-images/tiff/laptops.tiff" in
              let img2 = load_tiff_image "test-images/tiff/laptops-2.tiff" in
              let diffOutput, _, _, _ = Diff.compare img1 img2 () in
              let originalDiff =
                load_png_image "test-images/tiff/laptops-diff.png"
              in
              let diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _ =
                Output_Diff.compare originalDiff diffOutput ()
              in
              if diffOfDiffPixels > 0 then (
                Tiff.IO.saveImage diffOutput "test-images/tiff/_diff-output.png";
                Png.IO.saveImage diffMaskOfDiff
                  "test-images/tiff/_diff-of-diff.png");
              check int "diffOfDiffPixels" 0 diffOfDiffPixels;
              check (float 0.001) "diffOfDiffPercentage" 0.0
                diffOfDiffPercentage);
        ] );
    ]

let () =
  if Sys.os_type = "Unix" then run_tiff_tests ()
  else print_endline "Skipping TIFF tests on Windows systems"
