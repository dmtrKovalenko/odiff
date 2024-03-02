module C = Configurator.V1

let _ =
  C.main ~name:"odiff-c-lib-package-resolver" (fun _c ->
      let spng_include_path = Sys.getenv "SPNG_INCLUDE_PATH" |> String.trim in
      let spng_lib_path = Sys.getenv "SPNG_LIB_PATH" |> String.trim in
      let libspng = spng_lib_path ^ "/libspng_static.a" in
      let jpeg_include_path = Sys.getenv "JPEG_INCLUDE_PATH" |> String.trim in
      let jpeg_lib_path = Sys.getenv "JPEG_LIB_PATH" |> String.trim in
      let libjpeg = jpeg_lib_path ^ "/libjpeg.a" in
      let tiff_include_path = Sys.getenv "TIFF_INCLUDE_PATH" |> String.trim in
      let tiff_lib_path = Sys.getenv "TIFF_LIB_PATH" |> String.trim in
      let libtiff = tiff_lib_path ^ "/libtiff.a" in
      let z_lib_path = Sys.getenv "Z_LIB_PATH" |> String.trim in
      let zlib = z_lib_path ^ "/libz.a" in
      C.Flags.write_sexp "png_write_c_flags.sexp" [ "-I" ^ spng_include_path ];
      C.Flags.write_sexp "png_write_c_library_flags.sexp" [ libspng; zlib ];
      C.Flags.write_sexp "png_write_flags.sexp" [ "-cclib"; libspng ];
      C.Flags.write_sexp "png_c_flags.sexp" [ "-I" ^ spng_include_path ];
      C.Flags.write_sexp "png_c_library_flags.sexp" [ libspng; zlib ];
      C.Flags.write_sexp "png_flags.sexp" [ "-cclib"; libspng ];
      C.Flags.write_sexp "jpg_c_flags.sexp" [ "-I" ^ jpeg_include_path ];
      C.Flags.write_sexp "jpg_c_library_flags.sexp" [ libjpeg ];
      C.Flags.write_sexp "jpg_flags.sexp" [ "-cclib"; libjpeg ];
      C.Flags.write_sexp "tiff_c_flags.sexp" [ "-I" ^ tiff_include_path ];
      C.Flags.write_sexp "tiff_c_library_flags.sexp" [ libtiff; zlib ];
      C.Flags.write_sexp "tiff_flags.sexp" [ "-cclib"; libtiff ])
