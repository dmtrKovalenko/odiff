open Odiff.ImageIO;
open Odiff.Diff;

let getTypeFromFilename = filename =>
  Filename.extension(filename)
  |> (
    fun
    | ".png" => `png
    | ".jpg"
    | ".jpeg" => `jpg
    | ".bmp" => `bmp
    | ".tiff" => `tiff
    | f => failwith("This format is not supported: " ++ f)
  );

let getIOModule =
  fun
  | `png => ((module ODiffIO.Png.IO): (module ImageIO))
  | `jpg => ((module ODiffIO.Jpg.IO): (module ImageIO))
  | `bmp => ((module ODiffIO.Bmp.IO): (module ImageIO))
  | `tiff => ((module ODiffIO.Tiff.IO): (module ImageIO));

type diffResult('output) = {
  exitCode: int,
  diff: option('output),
};

let main =
    (
      img1,
      img2,
      img1Type,
      img2Type,
      diffPath,
      threshold,
      outputDiffMask,
      failOnLayoutChange,
      diffColorHex,
      stdoutParsableString,
      img1IsBuffer,
      img2IsBuffer,
      antialiasing,
      ignoreRegions,
    ) => {
  let img1Type =
    switch (img1Type) {
    | `auto when img1IsBuffer =>
      failwith("--base-type has to be not auto, when using buffer as input")
    | `auto => getTypeFromFilename(Filename.extension(img1))
    | `bmp => `bmp
    | `jpg => `jpg
    | `png => `png
    | `tiff => `tiff
    };

  let img2Type =
    switch (img2Type) {
    | `auto when img2IsBuffer =>
      failwith(
        "--compare-type has to be not auto, when using buffer as input",
      )
    | `auto => getTypeFromFilename(Filename.extension(img1))
    | `bmp => `bmp
    | `jpg => `jpg
    | `png => `png
    | `tiff => `tiff
    };

  module IO1 = (val getIOModule(img1Type));
  module IO2 = (val getIOModule(img2Type));

  module Diff = MakeDiff(IO1, IO2);

  let img1 =
    if (img1IsBuffer) {
      IO1.loadImageFromBuffer(img1);
    } else {
      IO1.loadImageFromPath(img1);
    };

  let img2 =
    if (img2IsBuffer) {
      IO2.loadImageFromBuffer(img2);
    } else {
      IO2.loadImageFromPath(img2);
    };

  let {diff, exitCode} =
    Diff.diff(
      img1,
      img2,
      ~outputDiffMask,
      ~threshold,
      ~failOnLayoutChange,
      ~antialiasing,
      ~ignoreRegions,
      ~diffPixel=
        Color.ofHexString(diffColorHex)
        |> (
          fun
          | Some(col) => col
          | None => (255, 0, 0) // red
        ),
      (),
    )
    |> Print.printDiffResult(stdoutParsableString)
    |> (
      fun
      | Layout => {diff: None, exitCode: 21}
      | Pixel((diffOutput, diffCount, stdoutParsableString))
          when diffCount == 0 => {
          exitCode: 0,
          diff: Some(diffOutput),
        }
      | Pixel((diffOutput, diffCount, diffPercentage)) => {
          IO1.saveImage(diffOutput, diffPath);
          {exitCode: 22, diff: Some(diffOutput)};
        }
    );

  IO1.freeImage(img1);
  IO2.freeImage(img2);

  switch (diff) {
  | Some(output) when outputDiffMask => IO1.freeImage(output)
  | _ => ()
  };

  exit(exitCode);
};
