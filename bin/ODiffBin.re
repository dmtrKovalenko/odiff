open Cmdliner;

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

let diffMask = {
  Arg.(
    value
    & flag
    & info(
        ["dm", "diff-mask"],
        ~docv="DIFF_IMAGE",
        ~doc="Output only changed pixel over transparent background.",
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

let parsableOutput =
  Arg.(
    value
    & flag
    & info(
        ["parsable-stdout"],
        ~docv="PARSABLE_OUTPUT",
        ~doc="Stdout parsable output",
      )
  );

let diffColor =
  Arg.(
    value
    & opt(string, "")
    & info(
        ["diff-color"],
        ~doc=
          "Color used to highlight different pixels in the output (in hex format e.g. #cd2cc9).",
      )
  );

let antialiasing = {
  Arg.(
    value
    & flag
    & info(
        ["aa", "antialiasing"],
        ~doc=
          "With this flag enabled, antialiased pixels are not counted to the diff of an image",
      )
  );
};

let ignoreRegions = {
  Arg.(
    value
    & opt(
        list(
          ~sep=',',
          t2(~sep='-', t2(~sep=':', int, int), t2(~sep=':', int, int)),
        ),
        [],
      )
    & info(
        ["i", "ignore"],
        ~doc=
          "An array of regions to ignore in the diff. One region looks like \"x1:y1-x2:y2\". Multiple regions are separated with a ','.",
      )
  );
};

let cmd = {
  let man = [
    `S(Manpage.s_description),
    `P("$(tname) is the fastest pixel-by-pixel image comparison tool."),
    `P("Supported image types: .png, .jpg, .jpeg, .bitmap"),
  ];

  (
    Term.(
      const(Main.main)
      $ base
      $ comp
      $ diffPath
      $ threshold
      $ diffMask
      $ failOnLayout
      $ diffColor
      $ parsableOutput
      $ antialiasing
      $ ignoreRegions
    ),
    Term.info(
      "odiff",
      ~version="2.4.2",
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
