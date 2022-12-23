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

let readFromStdin = () => {
  /* We use 65536 because that is the size of OCaml's IO buffers. */
  let chunk_size = 65536;
  let buffer = Buffer.create(chunk_size);
  let rec loop = () => {
    Buffer.add_channel(buffer, stdin, chunk_size);
    loop();
  };
  try(loop()) {
  | End_of_file => Buffer.contents(buffer)
  };
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
      antialiasing,
      ignoreRegions,
    ) => {
  let img1Type =
    switch (img1Type) {
    | `auto when img1 == "_" =>
      failwith("--base-type has to be not auto, when using buffer as input")
    | `auto => getTypeFromFilename(img1)
    | `bmp => `bmp
    | `jpg => `jpg
    | `png => `png
    | `tiff => `tiff
    };

  let img2Type =
    switch (img2Type) {
    | `auto when img2 == "_" =>
      failwith(
        "--compare-type has to be not auto, when using buffer as input",
      )
    | `auto => getTypeFromFilename(img2)
    | `bmp => `bmp
    | `jpg => `jpg
    | `png => `png
    | `tiff => `tiff
    };

  module IO1 = (val getIOModule(img1Type));
  module IO2 = (val getIOModule(img2Type));

  module Diff = MakeDiff(IO1, IO2);

  let img1 =
    switch (img1) {
    | "_" =>
      if (!stdoutParsableString) {
        print_endline("Please provide the buffer for the base image:");
      };
      readFromStdin() |> IO1.loadImageFromBuffer;
    | path => IO1.loadImageFromPath(path)
    };

  let img2 =
    switch (img2) {
    | "_" =>
      if (!stdoutParsableString) {
        print_endline("Please provide the buffer for the compare image:");
      };
      readFromStdin() |> IO2.loadImageFromBuffer;
    | path => IO2.loadImageFromPath(path)
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
