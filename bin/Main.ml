open Odiff.ImageIO
open Odiff.Diff

let getIOModule filename =
  match Filename.extension filename with
  | ".png" -> (module ODiffIO.Png.IO : ImageIO)
  | ".jpg" | ".jpeg" -> (module ODiffIO.Jpg.IO : ImageIO)
  | ".bmp" -> (module ODiffIO.Bmp.IO : ImageIO)
  | ".tiff" -> (module ODiffIO.Tiff.IO : ImageIO)
  | "" ->
      failwith
        ("Usage: " ^ Sys.argv.(0)
       ^ " <base_image_path> <image_to_compare_path> <output_png_path>")
  | f -> failwith ("This format is not supported: " ^ f)

type 'output diffResult = { exitCode : int; diff : 'output option }

(* Arguments must remain positional for the cmd parser lib that we use *)
let main img1Path img2Path diffPath threshold outputDiffMask failOnLayoutChange
    diffColorHex toEmitStdoutParsableString antialiasing ignoreRegions diffLines
    disableGcOptimizations =
  (*
      We do not need to actually maintain memory size of the allocated RAM by odiff, so we are
      increasing the minor memory size to avoid most of the possible deallocations. For sure it is 
      not possible be sure that it won't be run in OCaml because we allocate the Stack and Queue

      By default set the minor heap size to 256mb on 64bit machine
  *)
  if not disableGcOptimizations then
    Gc.set
      {
        (Gc.get ()) with
        Gc.minor_heap_size = 64_000_000;
        Gc.stack_limit = 2_048_000;
        Gc.window_size = 25;
      };

  let module IO1 = (val getIOModule img1Path) in
  let module IO2 = (val getIOModule img2Path) in
  let module Diff = MakeDiff (IO1) (IO2) in
  let img1 = IO1.loadImage img1Path in
  let img2 = IO2.loadImage img2Path in
  let { diff; exitCode } =
    Diff.diff img1 img2 ~outputDiffMask ~threshold ~failOnLayoutChange
      ~antialiasing ~ignoreRegions ~diffLines
      ~diffPixel:
        (match Color.ofHexString diffColorHex with
        | Some c -> c
        | None -> redPixel)
      ()
    |> Print.printDiffResult toEmitStdoutParsableString
    |> function
    | Layout -> { diff = None; exitCode = 21 }
    | Pixel (diffOutput, diffCount, stdoutParsableString, _) when diffCount = 0
      ->
        { exitCode = 0; diff = Some diffOutput }
    | Pixel (diffOutput, diffCount, diffPercentage, _) ->
        IO1.saveImage diffOutput diffPath;
        { exitCode = 22; diff = Some diffOutput }
  in
  IO1.freeImage img1;
  IO2.freeImage img2;
  (match diff with
  | Some output when outputDiffMask -> IO1.freeImage output
  | _ -> ());

  (*Gc.print_stat stdout;*)
  exit exitCode
