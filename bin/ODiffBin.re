open Pastel;
open Cmdliner;

let main = (img1Path, img2Path, diffPath, threshold, diffImage) => {
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

    Odiff.ImageIO.saveImage(diffPath, diff);
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

let diff =
  Arg.(
    value
    & pos(2, file, "")
    & info([], ~docv="DIFF", ~doc="Diff output path (.png only)")
  );

let image1 =
  Arg.(
    value
    & pos(0, file, "")
    & info([], ~docv="IMAGE1", ~doc="Path to first image")
  );

let image2 =
  Arg.(
    value
    & pos(1, file, "")
    & info([], ~docv="IMAGE2", ~doc="Path to second image")
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

let cmd = {
  let man = [
    `S(Manpage.s_description),
    `P("$(tname) is the fastest pixel-by-pixel image comparison tool."),
    `P("Supported image types: .png, .jpg, .jpg"),
  ];

  (
    Term.(const(main) $ image1 $ image2 $ diff $ threshold $ diffImage),
    Term.info(
      "odiff",
      ~version="v1.0.4",
      ~doc="Find difference between 2 images.",
      ~man,
    ),
  );
};

let () = Term.exit @@ Term.eval(cmd);