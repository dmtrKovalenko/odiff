open Cmdliner
open Term
open Arg

let diffPath =
  value & pos 2 string ""
  & info [] ~docv:"DIFF" ~doc:"Diff output path (.png only)"

let base =
  value & pos 0 file "" & info [] ~docv:"BASE" ~doc:"Path to base image"

let comp =
  value & pos 1 file ""
  & info [] ~docv:"COMPARING" ~doc:"Path to comparing image"

let threshold =
  value & opt float 0.1
  & info [ "t"; "threshold" ] ~docv:"THRESHOLD"
      ~doc:"Color difference threshold (from 0 to 1). Less more precise."

let diffMask =
  value & flag
  & info [ "dm"; "diff-mask" ] ~docv:"DIFF_IMAGE"
      ~doc:"Output only changed pixel over transparent background."

let failOnLayout =
  value & flag
  & info [ "fail-on-layout" ] ~docv:"FAIL_ON_LAYOUT"
      ~doc:
        "Do not compare images and produce output if images layout is \
         different."

let parsableOutput =
  value & flag
  & info [ "parsable-stdout" ] ~docv:"PARSABLE_OUTPUT"
      ~doc:"Stdout parsable output"

let diffColor =
  value & opt string ""
  & info [ "diff-color" ]
      ~doc:
        "Color used to highlight different pixels in the output (in hex format \
         e.g. #cd2cc9)."

let antialiasing =
  value & flag
  & info [ "aa"; "antialiasing" ]
      ~doc:
        "With this flag enabled, antialiased pixels are not counted to the \
         diff of an image"

let diffLines =
  value & flag
  & info [ "output-diff-lines" ]
      ~doc:
        "With this flag enabled, output result in case of different images \
         will output lines for all the different pixels"

let disableGcOptimizations =
  value & flag
  & info [ "reduce-ram-usage" ]
      ~doc:
        "With this flag enabled odiff will use less memory, but will be slower \
         in some cases."

let ignoreRegions =
  value
  & opt
      (list ~sep:',' (t2 ~sep:'-' (t2 ~sep:':' int int) (t2 ~sep:':' int int)))
      []
  & info [ "i"; "ignore" ]
      ~doc:
        "An array of regions to ignore in the diff. One region looks like \
         \"x1:y1-x2:y2\". Multiple regions are separated with a ','."

let cmd =
  const Main.main $ base $ comp $ diffPath $ threshold $ diffMask $ failOnLayout
  $ diffColor $ parsableOutput $ antialiasing $ ignoreRegions $ diffLines
  $ disableGcOptimizations

let version =
  match Build_info.V1.version () with
  | None -> "dev"
  | Some v -> Build_info.V1.Version.to_string v

let info =
  let man =
    [
      `S Manpage.s_description;
      `P "$(tname) is the fastest pixel-by-pixel image comparison tool.";
      `P "Supported image types: .png, .jpg, .jpeg, .tiff";
    ]
  in
  Cmd.info "odiff" ~version ~doc:"Find difference between 2 images."
    ~exits:
      [
        Cmd.Exit.info 0 ~doc:"on image match";
        Cmd.Exit.info 21 ~doc:"on layout diff when --fail-on-layout";
        Cmd.Exit.info 22 ~doc:"on image pixel difference";
      ]
    ~man

let cmd = Cmd.v info cmd
let () = Cmd.eval cmd |> Stdlib.exit
