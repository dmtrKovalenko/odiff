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
    exit(21);
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

    let t = Odiff.PerfTest.now("save")

    Odiff.ImageIO.saveImage(diffPath, diffOutput);
    Odiff.PerfTest.cycle(t)
    exit(22);
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
        ~doc=
          "Do not compare images and produce output if images layout is different.",
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
      ~exits=[
        Term.exit_info(0, ~doc="on image match"),
        Term.exit_info(21, ~doc="on layout diff when --fail-on-layout"),
        Term.exit_info(22, ~doc="on image pixel difference"),
        ...Term.default_error_exits,
      ],
      ~man,
    ),
  );
};

let () = Term.eval(cmd) |> Term.exit;