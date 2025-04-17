open Odiff.Diff

let esc = "\027["
let red = esc ^ "31m"
let green = esc ^ "32m"
let bold = esc ^ "1m"
let dim = esc ^ "2m"
let reset = esc ^ "0m"

let printDiffResult makeParsableOutput result =
  (match (result, makeParsableOutput) with
  | Layout, true -> ()
  | Layout, false ->
      Format.printf "%s%sFailure!%s Images have different layout.\n" red bold
        reset
  | Pixel (_output, diffCount, diffPercentage, stack, coords), true
    when not (Stack.is_empty stack) || coords <> [] ->
      let lines_str =
        if Stack.is_empty stack then ";" else
        ";" ^ (stack |> Stack.fold (fun acc line -> (line |> Int.to_string) ^ "," ^ acc) "")
      in
      let coords_str =
        if coords = [] then "" else
        let coord_to_str (y, ranges) =
          let ranges_str = ranges |> List.map (fun (start, end_) ->
            Printf.sprintf "%d-%d" start end_) |> String.concat ","
          in
          Printf.sprintf "%d:%s" y ranges_str
        in
        ";" ^ String.concat "|" (List.map coord_to_str coords)
      in
      Int.to_string diffCount ^ ";"
      ^ Float.to_string diffPercentage
      ^ lines_str
      ^ coords_str
      |> print_endline
  | Pixel (_output, diffCount, diffPercentage, _, _), true ->
      Int.to_string diffCount ^ ";" ^ Float.to_string diffPercentage
      |> print_endline
  | Pixel (_output, diffCount, _percentage, _lines, _), false when diffCount == 0
    ->
      Format.printf
        "%s%sSuccess!%s Images are equal.\n%sNo diff output created.%s\n" green
        bold reset dim reset
  | Pixel (_output, diffCount, diffPercentage, _lines, _), false ->
      Format.printf
        "%s%sFailure!%s Images are different.\n\
         Different pixels: %s%s%i (%f%%)%s\n"
        red bold reset red bold diffCount diffPercentage reset);

  result
