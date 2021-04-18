(lang dune 2.8)

(use_standard_c_and_cxx_flags true)
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
 (depends
  dune
  (reason (and (>= 3.6.0) (< 4.0.0)))
  (ocaml (and (>= 4.10.0) (< 5.0.0)))
 )
)

(package
 (name odiff-io)
 (depends
  dune
  conf-libpng
  odiff-core
  (camlimages (= 5.4.0))
  (reason (and (>= 3.6.0) (< 4.0.0)))
  (ocaml (and (>= 4.10.0) (< 4.11.0)))
 )
)
