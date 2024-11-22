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
    Increase amount of allowed overhead to reduce amount of GC work and cycles.
    we target 1-2 minor collections per run which is the best tradeoff between
    amount of memory allocated and time spend on GC.

    For sure it depends on the image size and architecture. Primary target x86_64
  *)
  if not disableGcOptimizations then
    Gc.set
      {
        (Gc.get ()) with
        (* 16MB is a reasonable value for minor heap size *)
        minor_heap_size = 2 * 1024 * 1024;
        (* Double the minor heap *)
        major_heap_increment = 2 * 1024 * 1024;
        (* Reasonable high value to reduce major GC frequency *)
        space_overhead = 500;
        (* Disable compaction *)
        max_overhead = 1_000_000;
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
        diffPath |> Option.iter (IO1.saveImage diffOutput);
        { exitCode = 22; diff = Some diffOutput }
  in
  IO1.freeImage img1;
  IO2.freeImage img2;
  (match diff with
  | Some output when outputDiffMask -> IO1.freeImage output
  | _ -> ());

  (* Gc.print_stat stdout; *)
  exit exitCode
