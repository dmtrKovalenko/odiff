
type 'a t = {length: int; front: 'a list; back: 'a list}

let empty = {length= 0; front= []; back= []}

let push {length; front; back} v = {length= length + 1; front; back= v :: back}

let length {length; _} = length

let pop {length; front; back} =
  match front with
  | [] -> (
    match List.rev back with
    | [] ->
        None
    | x :: xs ->
        Some (x, {front= xs; length= length - 1; back= []}) )
  | x :: xs ->
      Some (x, {front= xs; length= length - 1; back})