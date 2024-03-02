external read_jpeg_image :
  string ->
  int
  * int
  * (int32, Bigarray.int32_elt, Bigarray.c_layout) Bigarray.Array1.t
  * 'a = "read_jpeg_file_to_tuple"

external cleanup_jpg : 'a -> unit = "cleanup_jpg" [@@noalloc]
