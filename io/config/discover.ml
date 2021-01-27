module C = Configurator.V1


let () =
C.main ~name:"odiff-c-lib-package-resolver" (fun c ->
let resolved_cflags_for_windows = Unix.getenv("CFLAGS") |> String.trim in
let resolved_libsflags_for_windows = Unix.getenv("LDFLAGS") |> String.trim in
let default : C.Pkg_config.package_conf =
  { libs   = ["libpng"]
  ; cflags = []
  }
in
let _static_or_not_flags = match Sys.os_type with
  | "Unix" -> ["-static"]
  | _ -> []
in
let conf =
  match C.Pkg_config.get c with
  | None -> default
  | Some pc ->
     match (C.Pkg_config.query pc ~package:"libpng") with
     | None -> default
     | Some deps -> deps

in


if (resolved_cflags_for_windows != String.concat "" conf.cflags) 
then 
 Printf.printf "\nAuto resolved c flags from env are different from pkg-config results, \n PKG-CONFIG: %s \n CLFAGS: %s" (String.concat " " conf.cflags) resolved_cflags_for_windows;

if (resolved_libsflags_for_windows != String.concat "" conf.libs) 
then 
 Printf.printf "\nAuto resolved libs flags from env are different from pkg-config results, \n PKG-CONFIG: %s \n LDFLAGS: %s" (String.concat " " conf.libs) resolved_libsflags_for_windows;


C.Flags.write_sexp "c_flags.sexp"         (String.split_on_char ' ' resolved_cflags_for_windows);
C.Flags.write_sexp "c_library_flags.sexp" (String.split_on_char ' ' resolved_libsflags_for_windows))

