open Odiff.Diff;

let printDiffResult = (makeParsableOutput, result) => {
  (
    switch (result, makeParsableOutput) {
    | (Layout, true) => ""
    | (Layout, false) =>
      <Pastel>
        <Pastel color=Red bold=true> "Failure! " </Pastel>
        "Images have different layout.\n"
      </Pastel>

    // SUCCESS
    | (Pixel((_output, diffCount, _percentage, _lines)), true)
        when diffCount === 0 => ""
    | (Pixel((_output, diffCount, _percentage, _lines)), false)
        when diffCount === 0 =>
      <Pastel>
        <Pastel color=Green bold=true> "Success! " </Pastel>
        "Images are equal.\n"
        <Pastel dim=true> "No diff output created." </Pastel>
      </Pastel>

    // FAILURE
    | (Pixel((_output, diffCount, diffPercentage, stack)), true) when !Stack.is_empty(stack) =>
      Int.to_string(diffCount)
      ++ ";"
      ++ Float.to_string(diffPercentage)
      ++ ";"
      ++ (
        stack
        |> Stack.fold(
             (acc, line) => (line |> Int.to_string) ++ "," ++ acc,
             "",
           )
      )

    | (Pixel((_output, diffCount, diffPercentage, _)), true) =>
      Int.to_string(diffCount) ++ ";" ++ Float.to_string(diffPercentage)

    | (Pixel((_output, diffCount, diffPercentage, _lines)), false) =>
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
