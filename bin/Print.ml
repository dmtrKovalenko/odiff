open Odiff.Diff

let printDiffResult makeParsableOutput result =
  (match (result, makeParsableOutput) with
  | Layout, true -> ""
  | Layout, false ->
      Pastel.createElement
        ~children:
          [
            (Pastel.createElement ~color:Red ~bold:true ~children:[ "Failure!" ]
               () [@JSX]);
            " Images have different layout.\n";
          ]
        () [@JSX]
  | Pixel (_output, diffCount, _percentage, _lines), true when diffCount == 0 ->
      ""
  | Pixel (_output, diffCount, _percentage, _lines), false when diffCount == 0
    ->
      Pastel.createElement
        ~children:
          [
            (Pastel.createElement ~color:Green ~bold:true
               ~children:[ "Success!" ] () [@JSX]);
            " Images are equal.\n";
            (Pastel.createElement ~dim:true
               ~children:[ "No diff output created." ]
               () [@JSX]);
          ]
        () [@JSX]
  | Pixel (_output, diffCount, diffPercentage, stack), true
    when not (Stack.is_empty stack) ->
      Int.to_string diffCount ^ ";"
      ^ Float.to_string diffPercentage
      ^ ";"
      ^ (stack
        |> Stack.fold (fun acc line -> (line |> Int.to_string) ^ "," ^ acc) "")
  | Pixel (_output, diffCount, diffPercentage, _), true ->
      Int.to_string diffCount ^ ";" ^ Float.to_string diffPercentage
  | Pixel (_output, diffCount, diffPercentage, _lines), false ->
      Pastel.createElement
        ~children:
          [
            (Pastel.createElement ~color:Red ~bold:true ~children:[ "Failure!" ]
               () [@JSX]);
            " Images are different.\n";
            "Different pixels: ";
            (Pastel.createElement ~color:Red ~bold:true
               ~children:[ Printf.sprintf "%i (%f%%)" diffCount diffPercentage ]
               () [@JSX]);
          ]
        () [@JSX])
  |> Console.log;
  result
