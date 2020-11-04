exception ImagesArgsRequired;

type options = {
  fullDiff: bool,
  threshold: option(float),
  diffColor: option((int, int, int)),
};

let rec reduce = (fn, acc, list) =>
  switch (list) {
  | [] => acc
  | [n, ...ns] => fn(n, reduce(fn, acc, ns))
  };

let defaultOptions = {fullDiff: false, threshold: None, diffColor: None};

let matchValuableArg = (arg, value, options) => {
  switch (arg) {
  | "--threshold"
  | "-t" => {...options, threshold: Some(value |> Float.of_string)}
  | _ => raise(Invalid_argument(arg))
  };
};

let matchBoolArgs = (arg, options) =>
  switch (arg) {
  | "--diff-image" => {...options, fullDiff: true}
  | _ => raise(Invalid_argument(arg))
  };

let processOptions =
  reduce(
    (rawArg, options) => {
      switch (rawArg |> String.split_on_char('=')) {
      | [] => raise(Invalid_argument(rawArg))
      | [boolArg] => matchBoolArgs(boolArg, options)
      | [valueArg, value] => matchValuableArg(valueArg, value, options)
      | _ => raise(Invalid_argument(rawArg))
      }
    },
    defaultOptions,
  );

let processArgs =
  fun
  | [] => raise(ImagesArgsRequired)
  | [_] => raise(ImagesArgsRequired)
  | [_, _] => raise(ImagesArgsRequired)
  | [img1, img2, diffPath] => (img1, img2, diffPath, defaultOptions)
  | [img1, img2, diffPath, ...tail] => (
      img1,
      img2,
      diffPath,
      processOptions(tail),
    );

Sys.argv
|> Array.to_list
|> List.tl
|> processArgs
|> (
  ((img1Path, img2Path, diffPath, options)) => {
    let img1 = Odiff.ImageIO.loadImage(img1Path);
    let img2 = Odiff.ImageIO.loadImage(img2Path);

    let diff =
      options.fullDiff
        ? Rgba32.copy(img1) : Rgba32.create(img1.width, img1.height);
    let t = Odiff.PerfTest.now("kek");
    Odiff.Diff.compare(img1, img2, diff);
    Odiff.PerfTest.cycle(t);
    Images.Rgba32(diff) |> Png.save(diffPath, []);
  }
);