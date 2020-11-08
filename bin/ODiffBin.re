open Core;
open Pastel;

let main =
    (img1Path, img2Path, diffPath, ~diffImage=false, ~threshold=0.1, ()) => {
  let img1 = Odiff.ImageIO.loadImage(img1Path);
  let img2 = Odiff.ImageIO.loadImage(img2Path);

  let diff =
    diffImage ? Rgba32.copy(img1) : Rgba32.create(img1.width, img1.height);

  let diffCount = Odiff.Diff.compare(img1, img2, diff, ~threshold, ());

  if (diffCount > 0) {
    Console.log(
      <Pastel>
        <Pastel color=Red bold=true> "Failure! " </Pastel>
        "Images are different.\n"
        "Different pixels: "
        <Pastel color=Red bold=true> {Int.to_string(diffCount)} </Pastel>
      </Pastel>,
    );

    Images.Rgba32(diff) |> Png.save(diffPath, []);
    exit(1);
  } else {
    Console.log(
      <Pastel>
        <Pastel color=Green bold=true> "Success! " </Pastel>
        "Images are equal.\n"
        <Pastel dim=true> "No diff output created." </Pastel>
      </Pastel>,
    );
  };
};

let () = {
  open Command.Let_syntax;

  let command =
    Command.basic(
      ~summary=
        <Pastel>
          "\nFind "
          <Pastel bold=true color=Cyan> "difference" </Pastel>
          " between 2 images. \nSupported image types: .png, .jpeg, .jpg."
        </Pastel>,
      {
        let%map_open img1Path = anon("[image 1 path]" %: string)
        and img2Path = anon("[image 2 path]" %: string)
        and diffPath =
          anon(
            <Pastel>
              "[diff "
              <Pastel bold=true underline=true> "png" </Pastel>
              " output path]"
            </Pastel>
            %: string,
          )
        and diffImage =
          flag(~doc="render diff over the base image", "-diff-image", no_arg)
        and baseThreshold =
          flag(
            "-threshold",
            optional(float),
            ~doc="0.1 color difference threshold (from 0 to 1)",
          );

        let threshold =
          switch (baseThreshold) {
          | Some(baseFloat) => Base.Float.to_float(baseFloat)
          | None => 0.1
          };

        () => main(img1Path, img2Path, diffPath, ~diffImage, ~threshold, ());
      },
    );

  Command.run(command, ~version="0.1");
};