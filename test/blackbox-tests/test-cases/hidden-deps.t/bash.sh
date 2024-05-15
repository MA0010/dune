#! /bin/bash
ver=`ocamlc -H x`
case "$ver" in
"No input files")
  # here, we have a compiler that supports -H flag
  # case for ITD set to false
  
  cat > dune-project << EOF
  (lang dune 3.15)
  (implicit_transitive_deps false)
  EOF 
  includes=`dune build --verbose ./run.exe 2>&1 | grep -E -o "\-H\s\S*" | sed s/\-H//g`
  includes="$(echo "${includes}" | tr -d '[:space:]')"
  if [ "$includes" = '.foo.objs/byte.foo.objs/byte.foo.objs/native.foo.objs/byte.foo.objs/native' ]; then
    echo "OKAY"
  else
    echo "ERROR"
  fi
  # case for ITD set to true
  cat > dune-project << EOF
  (lang dune 3.15)
  (implicit_transitive_deps true)
  EOF
  includes=`dune build --verbose ./run.exe 2>&1 | grep -E -o "\-I\s\S*" | sed s/\-I//g`
  includes="$(echo "${includes}" | tr -d '[:space:]')"
  if [ "$includes" = '.foo.objs/byte.foo.objs/byte.foo.objs/native.foo.objs/byte.foo.objs/native' ]; then
    echo "OKAY"
  else
    echo "ERROR"
  fi
  ;;
*)
  # here, we have a compiler that does not support -H flag
  # case for ITD set to false
  cat > dune-project << EOF
  (lang dune 3.15)
  (implicit_transitive_deps false)
  EOF 
  includes=`dune build --verbose ./run.exe 2>&1 | grep -E -o "\-I\s(.foo)\S*" | sed s/\-I//g`
  includes="$(echo "${includes}" | tr -d '[:space:]')"
  if [ "$includes" = '' ]; then
    echo "OKAY"
  else
    echo "ERROR"
  fi
  # case for ITD set to true
  cat > dune-project << EOF
  (lang dune 3.15)
  (implicit_transitive_deps true)
  EOF
  includes=`dune build --verbose ./run.exe 2>&1 | grep -E -o "\-I\s(.foo)\S*" | sed s/\-I//g`
  includes="$(echo "${includes}" | tr -d '[:space:]')"
  if [ "$includes" = '.foo.objs/byte.foo.objs/byte.foo.objs/native.foo.objs/byte.foo.objs/native' ]; then
    echo "OKAY"
  else
    echo "ERROR"
  fi
  ;;
ac









#if [ $ver == 5.2.0~beta2 ] || [ $ver == 5.2.0 ] || [ $ver == 5.2.0+options ] || [ $ver == 5.2.0+options ] || [ $ver == 5.2.0+statmemprof ] || [ $ver == 5.3.0+trunk ]; then
  # Run the command
#  FLAG=\-H
#  dune build --verbose ./run.exe 2>&1 | sed s/$FLAG/\-X/g | grep -E -o "\-X\s\S*"
#else
#  FLAG=\-I
#  dune build --verbose ./run.exe 2>&1 | sed s/$FLAG/\-X/g | grep -E -o "\-X\s(.foo)\S*" | sed -e '3d'
#fi