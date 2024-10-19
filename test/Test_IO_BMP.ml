open Alcotest

module Diff = Odiff.Diff.MakeDiff (Bmp.IO) (Bmp.IO)
module Output_Diff = Odiff.Diff.MakeDiff (Png.IO) (Bmp.IO)

let load_image path =
  match Bmp.IO.loadImage path with
  | exception ex -> fail (Printf.sprintf "Failed to load image: %s\nError: %s" path (Printexc.to_string ex))
  | img -> img

let load_png_image path =
  match Png.IO.loadImage path with
  | exception ex -> fail (Printf.sprintf "Failed to load image: %s\nError: %s" path (Printexc.to_string ex))
  | img -> img

let test_finds_difference_between_images () =
  let img1 = load_image "test-images/bmp/clouds.bmp" in
  let img2 = load_image "test-images/bmp/clouds-2.bmp" in
  let _, diffPixels, diffPercentage, _ = Diff.compare img1 img2 () in
  check int "diffPixels" 191 diffPixels;
  check (float 0.001) "diffPercentage" 0.076 diffPercentage

let test_diff_mask_no_mask_equal () =
  let img1 = load_image "test-images/bmp/clouds.bmp" in
  let img2 = load_image "test-images/bmp/clouds-2.bmp" in
  let _, diffPixels, diffPercentage, _ = Diff.compare img1 img2 ~outputDiffMask:false () in
  let img1 = load_image "test-images/bmp/clouds.bmp" in
  let img2 = load_image "test-images/bmp/clouds-2.bmp" in
  let _, diffPixelsMask, diffPercentageMask, _ = Diff.compare img1 img2 ~outputDiffMask:true () in
  check int "diffPixels" diffPixels diffPixelsMask;
  check (float 0.001) "diffPercentage" diffPercentage diffPercentageMask

let test_creates_correct_diff_output_image () =
  let img1 = load_image "test-images/bmp/clouds.bmp" in
  let img2 = load_image "test-images/bmp/clouds-2.bmp" in
  let diffOutput, _, _, _ = Diff.compare img1 img2 () in
  check bool "diffOutput" (Option.is_some diffOutput) true;
  let diffOutput = Option.get diffOutput in
  let originalDiff = load_png_image "test-images/bmp/clouds-diff.png" in
  let diffMaskOfDiff, diffOfDiffPixels, diffOfDiffPercentage, _ = Output_Diff.compare originalDiff diffOutput () in
  check bool "diffMaskOfDiff" (Option.is_some diffMaskOfDiff) true;
  let diffMaskOfDiff = Option.get diffMaskOfDiff in
  if diffOfDiffPixels > 0 then (
    Bmp.IO.saveImage diffOutput "test-images/bmp/_diff-output.png";
    Png.IO.saveImage diffMaskOfDiff "test-images/bmp/_diff-of-diff.png"
  );
  check int "diffOfDiffPixels" 0 diffOfDiffPixels;
  check (float 0.001) "diffOfDiffPercentage" 0.0 diffOfDiffPercentage

let () =
  run "IO" [
    "BMP", [
      test_case "finds difference between 2 images" `Quick test_finds_difference_between_images;
      test_case "Diff of mask and no mask are equal" `Quick test_diff_mask_no_mask_equal;
      test_case "Creates correct diff output image" `Quick test_creates_correct_diff_output_image;
    ];
  ]

