external load :
  string ->
  int
  * int
  * (int32, Bigarray.int32_elt, Bigarray.c_layout) Bigarray.Array1.t
  * 'a = "read_tiff_file_to_tuple"

external cleanup_tiff : 'a -> unit = "cleanup_tiff" [@@noalloc]
