open Odiff.ImageIO
open Odiff.Diff

let getIOModule filename =
  match Filename.extension filename with
  | ".png" -> (module ODiffIO.Png.IO : ImageIO)
  | ".jpg" | ".jpeg" -> (module ODiffIO.Jpg.IO : ImageIO)
  | ".bmp" -> (module ODiffIO.Bmp.IO : ImageIO)
  | ".tiff" -> (module ODiffIO.Tiff.IO : ImageIO)
  | f -> failwith ("This format is not supported: " ^ f)

type 'output diffResult = { exitCode : int; diff : 'output option }

let main img1Path img2Path diffPath threshold outputDiffMask failOnLayoutChange
    diffColorHex stdoutParsableString antialiasing ignoreRegions diffLines =
  let module IO1 = (val getIOModule img1Path) in
  let module IO2 = (val getIOModule img2Path) in
  let module Diff = MakeDiff (IO1) (IO2) in
  let img1 = IO1.loadImage img1Path in
  let img2 = IO2.loadImage img2Path in
  let { diff; exitCode } =
    Diff.diff img1 img2 ~outputDiffMask ~threshold ~failOnLayoutChange
      ~antialiasing ~ignoreRegions ~diffLines
      ~diffPixel:
        (Color.ofHexString diffColorHex |> function
         | Some col -> col
         | None -> (255, 0, 0))
      ()
    |> Print.printDiffResult stdoutParsableString
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
  exit exitCode
