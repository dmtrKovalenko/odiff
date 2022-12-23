external read_png_image:
  string =>
  (
    int,
    int,
    Bigarray.Array1.t(int32, Bigarray.int32_elt, Bigarray.c_layout),
    'a,
  ) =
  "read_png_file";

external read_png_buffer:
  (string, int) =>
  (
    int,
    int,
    Bigarray.Array1.t(int32, Bigarray.int32_elt, Bigarray.c_layout),
    'a,
  ) =
  "read_png_buffer";
