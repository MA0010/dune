include Stdune
module Digest = Dune_digest.Digest
module Cached_digest = Dune_digest.Cached_digest
module Console = Dune_console
module Metrics = Dune_metrics
module Log = Dune_util.Log
module Stringlike = Dune_util.Stringlike

module type Stringlike = Dune_util.Stringlike

module Persistent = Dune_util.Persistent
module Execution_env = Dune_util.Execution_env
module Glob = Dune_glob.V1
module Targets = Dune_targets
module Dep = Dune_deps.Dep
module Alias = Dune_deps.Alias
module File_selector = Dune_deps.File_selector
module Dpath = Dune_deps.Dpath
module Context_name = Dune_deps.Context_name
include No_io
include Dune_config

(* To make bug reports usable *)
let () = Printexc.record_backtrace true
let protect = Exn.protect
let protectx = Exn.protectx
