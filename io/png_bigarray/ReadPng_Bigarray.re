external read_png_image:
  string =>
  (
    int,
    int,
    Bigarray.Array1.t(int32, Bigarray.int32_elt, Bigarray.c_layout),
    'a,
  ) =
  "read_spng_file";

[@noalloc] external cleanup_png_bigarray: 'a => unit = "cleanup_png_bigarray";
