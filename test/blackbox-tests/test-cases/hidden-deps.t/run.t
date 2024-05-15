Should include Foo with -H:
  $ ver=`ocamlc -H x`
  > case "$ver" in
  >   "No input files")
  >     # here, we have a compiler that supports -H flag
  >     # case for ITD set to false
  >     cat > dune-project << EOF
  >     (lang dune 3.15)
  >     (implicit_transitive_deps false)
  >     EOF 
  >     includes=`dune build --verbose ./run.exe 2>&1 | grep -E -o "\-H\s\S*" | sed s/\-H//g`
  >     includes="$(echo "${includes}" | tr -d '[:space:]')"
  >     if [ "$includes" = '.foo.objs/byte.foo.objs/byte.foo.objs/native.foo.objs/byte.foo.objs/native' ]; then
  >       echo "OKAY"
  >     else
  >       echo "ERROR"
  >     fi
  >     # case for ITD set to true
  >     cat > dune-project << EOF
  >     (lang dune 3.15)
  >     (implicit_transitive_deps true)
  >     EOF
  >     includes=`dune build --verbose ./run.exe 2>&1 | grep -E -o "\-I\s\S*" | sed s/\-I//g`
  >     includes="$(echo "${includes}" | tr -d '[:space:]')"
  >     if [ "$includes" = '.foo.objs/byte.foo.objs/byte.foo.objs/native.foo.objs/byte.foo.objs/native' ]; then
  >       echo "OKAY"
  >     else
  >       echo "ERROR"
  >     fi
  >     ;;
  >   *)
  >     # here, we have a compiler that does not support -H flag
  >     # case for ITD set to false
  >     cat > dune-project << EOF
  >     (lang dune 3.15)
  >     (implicit_transitive_deps false)
  >     EOF 
  >     includes=`dune build --verbose ./run.exe 2>&1 | grep -E -o "\-I\s(.foo)\S*" | sed s/\-I//g`
  >     includes="$(echo "${includes}" | tr -d '[:space:]')"
  >     if [ "$includes" = '' ]; then
  >       echo "OKAY"
  >     else
  >       echo "ERROR"
  >     fi
  >     # case for ITD set to true
  >     cat > dune-project << EOF
  >     (lang dune 3.15)
  >     (implicit_transitive_deps true)
  >     EOF
  >     includes=`dune build --verbose ./run.exe 2>&1 | grep -E -o "\-I\s(.foo)\S*" | sed s/\-I//g`
  >     includes="$(echo "${includes}" | tr -d '[:space:]')"
  >     if [ "$includes" = '.foo.objs/byte.foo.objs/byte.foo.objs/native.foo.objs/byte.foo.objs/native' ]; then
  >       echo "OKAY"
  >     else
  >       echo "ERROR"
  >     fi
  >     ;;
  > esac
  OKAY
  OKAY


Test transitive deps can not be directly accessed, both for compiler versions supporting -H or not:
  $ dune build ./runf.exe 2>&1 | grep -v ocamlc
  File "runf.ml", line 1, characters 16-21:
  1 | let a = Bar.y + Foo.v
                      ^^^^^
  Error: Unbound module Foo

Test that with ITD, transitive deps are directly accessible 
  $ dune exec with_ITD/runf.exe 2>&1 | grep -v ocamlc
  18