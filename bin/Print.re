open Odiff.Diff;

let printDiffResult = (makeParsableOutput, result) => {
  (
    switch (result) {
    | Layout when makeParsableOutput => ""
    | Layout =>
      <Pastel>
        <Pastel color=Red bold=true> "Failure! " </Pastel>
        "Images have different layout.\n"
      </Pastel>

    // SUCCESS
    | Pixel((_output, diffCount, _percentage))
        when diffCount === 0 && makeParsableOutput => ""
    | Pixel((_output, diffCount, _percentage)) when diffCount === 0 =>
      <Pastel>
        <Pastel color=Green bold=true> "Success! " </Pastel>
        "Images are equal.\n"
        <Pastel dim=true> "No diff output created." </Pastel>
      </Pastel>

    // FAILURE
    | Pixel((_output, diffCount, diffPercentage)) when makeParsableOutput =>
      Int.to_string(diffCount) ++ ";" ++ Float.to_string(diffPercentage)

    | Pixel((_output, diffCount, diffPercentage)) =>
      <Pastel>
        <Pastel color=Red bold=true> "Failure! " </Pastel>
        "Images are different.\n"
        "Different pixels: "
        <Pastel color=Red bold=true>
          {Printf.sprintf("%i (%f%%)", diffCount, diffPercentage)}
        </Pastel>
      </Pastel>
    }
  )
  |> Console.log;

  result;
};
