[@noalloc]
external write_png_file: ('a, int, int, string) => unit = "write_png_file";

[@noalloc]
external write_png_buffer: (string, bytes, int, int) => unit =
  "write_png_buffer";

[@noalloc]
external write_png_bigarray:
  (
    string,
    Bigarray.Array1.t(int32, Bigarray.int32_elt, Bigarray.c_layout),
    int,
    int
  ) =>
  unit =
  "write_png_bigarray";
