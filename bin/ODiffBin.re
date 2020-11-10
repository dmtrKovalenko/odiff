open Pastel;
open Cmdliner;

let main =
    (img1Path, img2Path, diffPath, threshold, diffImage, failOnLayoutChange) => {
  let img1 = Odiff.ImageIO.loadImage(img1Path);
  let img2 = Odiff.ImageIO.loadImage(img2Path);

  switch (
    Odiff.Diff.diff(
      img1,
      img2,
      ~diffImage,
      ~threshold,
      ~failOnLayoutChange,
      (),
    )
  ) {
  | Layout =>
    Console.log(
      <Pastel>
        <Pastel color=Red bold=true> "Failure! " </Pastel>
        "Images have different layout.\n"
      </Pastel>,
    );
    exit(65);
  | Pixel((_, diffCount)) when diffCount == 0 =>
    Console.log(
      <Pastel>
        <Pastel color=Green bold=true> "Success! " </Pastel>
        "Images are equal.\n"
        <Pastel dim=true> "No diff output created." </Pastel>
      </Pastel>,
    );
    exit(0);
  | Pixel((diffOutput, diffCount)) =>
    Console.log(
      <Pastel>
        <Pastel color=Red bold=true> "Failure! " </Pastel>
        "Images are different.\n"
        "Different pixels: "
        <Pastel color=Red bold=true> {Int.to_string(diffCount)} </Pastel>
      </Pastel>,
    );

    Odiff.ImageIO.saveImage(diffPath, diffOutput);
    exit(1);
  };
};

let diffPath =
  Arg.(
    value
    & pos(2, string, "")
    & info([], ~docv="DIFF", ~doc="Diff output path (.png only)")
  );

let base =
  Arg.(
    value
    & pos(0, file, "")
    & info([], ~docv="BASE", ~doc="Path to base image")
  );

let comp =
  Arg.(
    value
    & pos(1, file, "")
    & info([], ~docv="COMPARING", ~doc="Path to comparing image")
  );

let threshold = {
  Arg.(
    value
    & opt(float, 0.1)
    & info(
        ["t", "threshold"],
        ~docv="THRESHOLD",
        ~doc="Color difference threshold (from 0 to 1). Less more precise.",
      )
  );
};

let diffImage = {
  Arg.(
    value
    & flag
    & info(
        ["di", "diff-image"],
        ~docv="DIFF_IMAGE",
        ~doc=
          "Render image to the diff output instead of transparent background.",
      )
  );
};

let failOnLayout =
  Arg.(
    value
    & flag
    & info(
        ["fail-on-layout"],
        ~docv="FAIL_ON_LAYOUT",
        ~doc="Fail and exit if images layouts are different",
      )
  );

let cmd = {
  let man = [
    `S(Manpage.s_description),
    `P("$(tname) is the fastest pixel-by-pixel image comparison tool."),
    `P("Supported image types: .png, .jpg, .jpeg, .bitmap"),
  ];

  (
    Term.(
      const(main)
      $ base
      $ comp
      $ diffPath
      $ threshold
      $ diffImage
      $ failOnLayout
    ),
    Term.info(
      "odiff",
      ~version="v1.0.4",
      ~doc="Find difference between 2 images.",
      ~man,
    ),
  );
};

let () = Term.eval(cmd) |> ignore;