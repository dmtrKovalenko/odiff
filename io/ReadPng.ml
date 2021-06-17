
external read_png_image: string -> int * int * int * 'b = "read_png_file_to_tuple"
external row_pointers_to_bigarray: 'b -> int ->  int -> int-> 'c = "row_pointers_to_bigarray"

external read_row: 'a -> int -> int -> 'b  = "read_row"

external set_pixel_data: 'a -> int -> int -> int * int * int -> unit = "set_pixel_data" [@@noalloc]

external write_png_file: 'a -> int -> int -> string -> unit = "write_png_file" [@@noalloc]

external write_png_buffer : string -> bytes -> int -> int -> unit = "write_png_buffer"

external free_row_pointers: 'a -> int -> unit = "free_row_pointers" [@@noalloc]

external create_empty_img: int -> int -> 'a = "create_empty_img" [@@noalloc]