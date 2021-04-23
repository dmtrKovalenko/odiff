(lang dune 2.8)

; Warning: The flag set for these foreign sources overrides the `:standard` set
; of flags. However the flags in this standard set are still added to the
; compiler arguments by Dune. This might cause unexpected issues. You can
; disable this warning by defining the option `(use_standard_c_and_cxx_flags <bool>)` 
; in your `dune-project` file. Setting this option to `true` will
; effectively prevent Dune from silently adding c-flags to the compiler
; arguments which is the new recommended behaviour.
(use_standard_c_and_cxx_flags false)

(generate_opam_files true)

(source (github dmtrKovalenko/odiff))
(license MIT)
(authors "Dmitriy Kovalenko")
(maintainers "https://dmtrkovalenko.dev" "dmtr.kovalenko@outlook.com")

(package
 (name odiff)
 (depends
  odiff-core
  odiff-io
 )
)

(package
 (name odiff-core)
 (synopsis "Pixel-by-pixel image difference algorithm")
 (depends
  dune
  (reason (and (>= 3.6.0) (< 4.0.0)))
  (ocaml (and (>= 4.10.0) (< 5.0.0)))
 )
)

(package
 (name odiff-io)
 (synopsis "Ready to use io for odiff-core")
 (depends
  dune
  conf-libpng
  odiff-core
  (camlimages (= 5.4.0))
  (reason (and (>= 3.6.0) (< 4.0.0)))
  (ocaml (and (>= 4.10.0) (< 4.11.0)))
 )
)
