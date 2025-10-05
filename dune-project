(lang dune 3.13)
(name neo4j_eio)
(formatting disabled)

(generate_opam_files true)

(source (github yourusername/neo4j_eio))
(license MIT)
(authors "Your Name")
(maintainers "your@email.com")

(package
 (name neo4j_eio)
 (synopsis "Neo4j Bolt driver for OCaml using Eio")
 (description "A modern, effects-based Neo4j driver for OCaml 5+ implementing the Bolt protocol with Eio for safe concurrent I/O")
 (depends
  (ocaml (>= 5.0))
  (dune (>= 3.13))
  eio
  cstruct
  angstrom
  tls-eio
  x509
  ca-certs
  domain-name
  (alcotest :with-test)
  (eio_main :with-test)
  (odoc :with-doc))
 (tags (database neo4j graph bolt eio)))
