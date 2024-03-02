open Bigarray

external write_png_bigarray :
  string -> (int32, int32_elt, c_layout) Array1.t -> int -> int -> unit
  = "write_png_bigarray"
[@@noalloc]
