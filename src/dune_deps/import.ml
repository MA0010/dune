include Stdune
module Digest = Dune_digest.Digest
module Cached_digest = Dune_digest.Cached_digest
module Stringlike = Dune_util.Stringlike

module type Stringlike = Dune_util.Stringlike

module Glob = Dune_glob.V1

(* To make bug reports usable *)
let () = Printexc.record_backtrace true
let protect = Exn.protect
let protectx = Exn.protectx
