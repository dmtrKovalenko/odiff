let now (name : string) = (name, ref (Sys.time ()))

let cycle (name, timepoint) ?(cycleName = "") () =
  Printf.printf "'%s %s' executed for: %f ms \n" name cycleName
    ((Sys.time () -. !timepoint) *. 1000.);
  timepoint := Sys.time ()

let ifTimeMore amount (name, timepoint) =
  (Sys.time () -. timepoint) *. 1000. > amount

let cycleIf point predicate = if predicate point then cycle point ()
