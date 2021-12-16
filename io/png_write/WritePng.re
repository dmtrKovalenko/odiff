open Bigarray;

[@noalloc]
external write_png_bigarray:
  (string, Array1.t(int32, int32_elt, c_layout), int, int) => unit =
  "write_png_bigarray";
