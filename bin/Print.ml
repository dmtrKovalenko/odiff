open Odiff.Diff

let printDiffResult makeParsableOutput result =
  let reset_ppf = Spectrum.prepare_ppf Format.str_formatter in
  (match (result, makeParsableOutput) with
  | Layout, true -> ()
  | Layout, false ->
      Spectrum.Simple.printf "@{<red>%s!@} Images have different layout.\n"
        "Failure!"
  | Pixel (_output, diffCount, diffPercentage, stack), true
    when not (Stack.is_empty stack) ->
      Int.to_string diffCount ^ ";"
      ^ Float.to_string diffPercentage
      ^ ";"
      ^ (stack
        |> Stack.fold (fun acc line -> (line |> Int.to_string) ^ "," ^ acc) "")
      |> print_endline
  | Pixel (_output, diffCount, diffPercentage, _), true ->
      Int.to_string diffCount ^ ";" ^ Float.to_string diffPercentage
      |> print_endline
  | Pixel (_output, diffCount, _percentage, _lines), false when diffCount == 0
    ->
      Spectrum.Simple.printf
        "@{<green><bold>Success!@} Images are equal.\n\
         @{<dim>No diff output created.@}"
  | Pixel (_output, diffCount, diffPercentage, _lines), false ->
      Spectrum.Simple.printf
        "@{<red,bold>Failure!@} Images are different.\n\
         Different pixels: @{<red,bold>%i (%f%%)@}" diffCount diffPercentage);

  reset_ppf ();
  result
