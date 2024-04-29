let ofHexString s =
  match String.length s with
  | (4 | 7) as len ->
      (let short = len = 4 in
       let r' =
         match short with true -> String.sub s 1 1 | false -> String.sub s 1 2
       in
       let g' =
         match short with true -> String.sub s 2 1 | false -> String.sub s 3 2
       in
       let b' =
         match short with true -> String.sub s 3 1 | false -> String.sub s 5 2
       in
       let r = int_of_string_opt ("0x" ^ r') in
       let g = int_of_string_opt ("0x" ^ g') in
       let b = int_of_string_opt ("0x" ^ b') in

       match (r, g, b) with
       | Some r, Some g, Some b when short ->
           Some ((16 * r) + r, (16 * g) + g, (16 * b) + b)
       | Some r, Some g, Some b -> Some (r, g, b)
       | _ -> None)
      |> Option.map (fun (r, g, b) ->
             (* Create rgba pixel value right after parsing *)
             let r = (r land 255) lsl 0 in
             let g = (g land 255) lsl 8 in
             let b = (b land 255) lsl 16 in
             let a = 255 lsl 24 in

             Int32.of_int (a lor b lor g lor r))
  | _ -> None
