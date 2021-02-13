let ofHexString = s =>
  if (String.length(s) == 4 || String.length(s) == 7) {
    let short = String.length(s) == 4;
    let r' = short ? String.sub(s, 1, 1) : String.sub(s, 1, 2);
    let g' = short ? String.sub(s, 2, 1) : String.sub(s, 3, 2);
    let b' = short ? String.sub(s, 3, 1) : String.sub(s, 5, 2);

    let r = int_of_string_opt("0x" ++ r');
    let g = int_of_string_opt("0x" ++ g');
    let b = int_of_string_opt("0x" ++ b');

    switch (r, g, b) {
    | (Some(r), Some(g), Some(b)) when short =>  Some((16 * r + r, 16 * g + g, 16 * b + b))
    | (Some(r), Some(g), Some(b)) => Some((r, g, b))
    | _ => None
    };
  } else {
    None;
  };
