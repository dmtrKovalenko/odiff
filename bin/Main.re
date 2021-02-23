open Odiff.Diff;
open Odiff.ImageIO;

let getIOModule = filename =>
  Filename.extension(filename)
  |> (
    fun
    | ".png" => ((module ODiffIO.PureC_IO.IO): (module ImageIO))
    | _ => ((module ODiffIO.CamlImagesIO.IO): (module ImageIO))
  );

type diffResult('output) = {
  message: string,
  exitCode: int,
  diff: option('output),
};

let main =
    (
      img1Path,
      img2Path,
      diffPath,
      threshold,
      outputDiffMask,
      failOnLayoutChange,
      diffColorHex,
    ) => {
  module IO1 = (val getIOModule(img1Path));
  module IO2 = (val getIOModule(img2Path));

  module Diff = MakeDiff(IO1, IO2);

  let img1 = IO1.loadImage(img1Path);
  let img2 = IO2.loadImage(img2Path);

  let {message, diff, exitCode} =
    switch (
      Diff.diff(
        img1,
        img2,
        ~outputDiffMask,
        ~threshold,
        ~failOnLayoutChange,
        ~diffPixel=
          Color.ofHexString(diffColorHex)
          |> (
            fun
            | Some(col) => col
            | None => (255, 0, 0) // red
          ),
        (),
      )
    ) {
    | Layout => {
        diff: None,
        exitCode: 21,
        message:
          <Pastel>
            <Pastel color=Red bold=true> "Failure! " </Pastel>
            "Images have different layout.\n"
          </Pastel>,
      }

    | Pixel((diffOutput, diffCount)) when diffCount == 0 => {
        exitCode: 0,
        diff: Some(diffOutput),
        message:
          <Pastel>
            <Pastel color=Green bold=true> "Success! " </Pastel>
            "Images are equal.\n"
            <Pastel dim=true> "No diff output created." </Pastel>
          </Pastel>,
      }

    | Pixel((diffOutput, diffCount)) =>
      IO1.saveImage(diffOutput, diffPath);

      {
        exitCode: 22,
        diff: Some(diffOutput),
        message:
          <Pastel>
            <Pastel color=Red bold=true> "Failure! " </Pastel>
            "Images are different.\n"
            "Different pixels: "
            <Pastel color=Red bold=true> {Int.to_string(diffCount)} </Pastel>
          </Pastel>,
      };
    };

  Console.log(message);

  IO1.freeImage(img1);
  IO2.freeImage(img2);

  switch (diff) {
  | Some(output) when outputDiffMask => IO1.freeImage(output)
  | _ => ()
  };

  exit(exitCode);
};
  