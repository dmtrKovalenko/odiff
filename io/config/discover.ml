module C = Configurator.V1

exception Pkg_Config_Resolution_Failed of string

type pkg_config_result = { cflags : string list; libs : string list }
type process_result = { exit_code : int; stdout : string; stderr : string }

let run_process ~env prog args =
  let stdout_fn = Filename.temp_file "stdout" ".tmp" in
  let stderr_fn = Filename.temp_file "stderr" ".tmp" in
  let openfile f =
    Unix.openfile f [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o666
  in
  let stdout = openfile stdout_fn in
  let stderr = openfile stderr_fn in
  let stdin, stdin_w = Unix.pipe () in
  Unix.close stdin_w;

  let pid =
    match env with
    | [] ->
        Unix.create_process prog
          (Array.of_list (prog :: args))
          stdin stdout stderr
    | _ ->
        let env_array = Array.of_list env in
        Unix.create_process_env prog
          (Array.of_list (prog :: args))
          env_array stdin stdout stderr
  in

  Unix.close stdin;
  Unix.close stdout;
  Unix.close stderr;

  let _, status = Unix.waitpid [] pid in

  let read_file filename =
    try
      let ic = open_in filename in
      let n = in_channel_length ic in
      let s = really_input_string ic n in
      close_in ic;
      s
    with
    | Sys_error msg -> Printf.sprintf "Error reading file %s: %s" filename msg
    | End_of_file ->
        Printf.sprintf "Unexpected end of file while reading %s" filename
  in

  let stdout_content = read_file stdout_fn in
  let stderr_content = read_file stderr_fn in

  Sys.remove stdout_fn;
  Sys.remove stderr_fn;

  let exit_code =
    match status with
    | Unix.WEXITED code -> code
    | Unix.WSIGNALED signal ->
        raise
          (Pkg_Config_Resolution_Failed
             (Printf.sprintf "Process killed by signal %d" signal))
    | Unix.WSTOPPED signal ->
        raise
          (Pkg_Config_Resolution_Failed
             (Printf.sprintf "Process stopped by signal %d" signal))
  in

  { exit_code; stdout = stdout_content; stderr = stderr_content }

let run_pkg_config _c lib =
  let pkg_config_path = Sys.getenv "PKG_CONFIG_PATH" in
  Printf.printf "Use PKG_CONFIG_PATH: %s\n" pkg_config_path;

  let env = [ "PKG_CONFIG_PATH=" ^ pkg_config_path ] in
  let c_flags_result = run_process ~env "pkg-config" [ "--cflags"; lib ] in
  let libs_result = run_process ~env "pkg-config" [ "--libs"; lib ] in

  if c_flags_result.exit_code = 0 && libs_result.exit_code == 0 then
    {
      cflags = c_flags_result.stdout |> C.Flags.extract_blank_separated_words;
      libs = libs_result.stdout |> C.Flags.extract_blank_separated_words;
    }
  else
    let std_errors =
      String.concat "\n" [ c_flags_result.stderr; libs_result.stderr ]
    in

    raise (Pkg_Config_Resolution_Failed std_errors)

let get_flags_from_env_or_run_pkg_conifg c ~env ~lib =
  match (Sys.getenv_opt (env ^ "_CFLAGS"), Sys.getenv_opt (env ^ "_LIBS")) with
  | Some cflags, Some lib ->
      {
        cflags = String.trim cflags |> C.Flags.extract_blank_separated_words;
        libs = lib |> C.Flags.extract_blank_separated_words;
      }
  | None, None -> run_pkg_config c lib
  | _ ->
      let err = "Missing CFLAGS or LIB env vars for " ^ env in
      raise (Pkg_Config_Resolution_Failed err)

let c_flags_to_ocaml_opt_flags flags =
  flags
  |> List.filter_map (function
       | opt when String.starts_with opt ~prefix:"-l" -> Some [ "-cclib"; opt ]
       | _ -> None)
  |> List.flatten

let () =
  C.main ~name:"odiff-c-lib-packae-resolver" (fun c ->
      let png_config =
        get_flags_from_env_or_run_pkg_conifg c ~env:"LIBPNG"
          ~lib:"libspng_static"
      in
      let tiff_config =
        get_flags_from_env_or_run_pkg_conifg c ~lib:"libtiff-4" ~env:"LIBTIFF"
      in
      let jpeg_config =
        get_flags_from_env_or_run_pkg_conifg c ~lib:"libturbojpeg"
          ~env:"LIBJPEG"
      in

      C.Flags.write_sexp "png_c_flags.sexp" png_config.cflags;
      C.Flags.write_sexp "png_c_library_flags.sexp" png_config.libs;
      C.Flags.write_sexp "png_write_c_flags.sexp" png_config.cflags;
      C.Flags.write_sexp "png_write_c_library_flags.sexp" png_config.libs;
      C.Flags.write_sexp "png_c_flags.sexp" png_config.cflags;
      C.Flags.write_sexp "jpg_c_flags.sexp" jpeg_config.cflags;
      C.Flags.write_sexp "jpg_c_library_flags.sexp" jpeg_config.libs;
      C.Flags.write_sexp "tiff_c_flags.sexp" tiff_config.cflags;
      C.Flags.write_sexp "tiff_c_library_flags.sexp" tiff_config.libs;

      (* this are ocamlopt flags that need to link c libs to ocaml compiler *)
      let png_ocamlopt_flags = png_config.libs |> c_flags_to_ocaml_opt_flags in
      C.Flags.write_sexp "png_write_flags.sexp" png_ocamlopt_flags;
      C.Flags.write_sexp "png_flags.sexp" png_ocamlopt_flags;

      jpeg_config.libs |> c_flags_to_ocaml_opt_flags
      |> C.Flags.write_sexp "jpg_flags.sexp";
      tiff_config.libs |> c_flags_to_ocaml_opt_flags
      |> C.Flags.write_sexp "tiff_flags.sexp")
