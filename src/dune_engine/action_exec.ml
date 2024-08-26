open Import
open Action_plugin
open Action_intf.Exec

let maybe_async =
  let maybe_async =
    lazy
      (match Config.(get background_actions) with
       | `Enabled -> Scheduler.async_exn
       | `Disabled -> fun f -> Fiber.return (f ()))
  in
  fun f -> (Lazy.force maybe_async) f
;;

module Duration = struct
  type t = float option

  let empty = None

  let combine x y =
    match x, y with
    | None, None -> None
    | Some _, None -> x
    | None, Some _ -> y
    | Some x, Some y -> Some (x +. y)
  ;;
end

module Produce = struct
  module State = struct
    type t = { duration : Duration.t }

    let empty = { duration = Duration.empty }
    let combine x { duration } = { duration = Duration.combine x.duration duration }
  end

  type 'a t = State.t -> ('a * State.t) Fiber.t

  let return : 'a. 'a -> 'a t = fun a state -> Fiber.return (a, state)

  let incr_duration : float -> 'a t =
    fun how_much state ->
    Fiber.return ((), State.combine state { duration = Some how_much })
  ;;

  let of_fiber (type a) (x : a Fiber.t) state : (a * State.t) Fiber.t =
    Fiber.map x ~f:(fun y -> y, state)
  ;;

  let run : 'a. State.t -> 'a t -> ('a * State.t) Fiber.t = fun x f -> f x

  let parallel_map : 'a 'b. 'a list -> f:('a -> 'b t) -> 'b list t =
    fun list ~f state ->
    let open Fiber.O in
    let+ list = Fiber.parallel_map list ~f:(fun x -> f x State.empty) in
    let result, durations = List.split list in
    let total_duration = List.fold_left durations ~init:state ~f:State.combine in
    result, total_duration
  ;;

  module O = struct
    open Fiber.O

    let ( let* ) : 'a 'b. 'a t -> ('a -> 'b t) -> 'b t =
      fun (type a b) (x : a t) (f : a -> b t) (state : State.t) : (b * State.t) Fiber.t ->
      let* res, state = x state in
      f res state
    ;;

    let ( >>| ) : 'a 'b. 'a t -> ('a -> 'b) -> 'b t =
      fun x f state ->
      let+ res, state = x state in
      f res, state
    ;;

    let ( let+ ) x f = x >>| f
  end
end

module Exec_result = struct
  module Error = struct
    type t =
      | User of User_message.t
      | Code of Code_error.t
      | Sys of string
      | Unix of Unix.error * string * string
      | Nonreproducible_build_cancelled

    (* We can't capture raw backtraces since they are not marshallable.
       We can convert those to marshallable backtrace slots, but we can't convert them
       back to re-raise exceptions with preserved backtraces. *)
    let of_exn (e : exn) =
      match e with
      | User_error.E msg -> User msg
      | Code_error.E err -> Code err
      | Sys_error msg -> Sys msg
      | Unix.Unix_error (err, call, args) -> Unix (err, call, args)
      | Memo.Non_reproducible Scheduler.Run.Build_cancelled ->
        Nonreproducible_build_cancelled
      | Memo.Cycle_error.E _ as e ->
        (* [Memo.Cycle_error.t] is hard to serialize and can only be raised during action
           execution with the dynamic dependencies plugin, which is not production-ready yet.
           For now, we just re-reraise it.
        *)
        reraise e
      | e ->
        Code
          { message = "unable to serialize exception"
          ; data = [ "exn", Exn.to_dyn e ]
          ; loc = None
          }
    ;;

    let to_exn (t : t) =
      match t with
      | User msg -> User_error.E msg
      | Code err -> Code_error.E err
      | Sys msg -> Sys_error msg
      | Unix (err, call, args) -> Unix.Unix_error (err, call, args)
      | Nonreproducible_build_cancelled ->
        Memo.Non_reproducible Scheduler.Run.Build_cancelled
    ;;
  end

  type ok =
    { dynamic_deps_stages : (Dep.Set.t * Dep.Facts.t) list
    ; duration : float option
    ; needed_deps : Dep.Set.t * Dep.Facts.t
    }

  type t = (ok, Error.t list) Result.t

  let ok_exn (t : t) =
    match t with
    | Ok t -> Fiber.return t
    | Error errs ->
      Fiber.reraise_all
        (List.map errs ~f:(fun e -> Exn_with_backtrace.capture (Error.to_exn e)))
  ;;
end

<<<<<<< HEAD
=======
module Action_res = struct
  type t =
    { done_or_more_deps : Action_plugin.done_or_more_deps
    ; needed_deps : Dep.Set.t
    }

  let union x y =
    match x, y with
    | ( { done_or_more_deps = x; needed_deps = a }
      , { done_or_more_deps = y; needed_deps = b } ) ->
      { done_or_more_deps = Action_plugin.done_or_more_deps_union x y
      ; needed_deps = Dep.Set.union a b
      }
  ;;

  let return ?needed_deps done_or_more_deps =
    let needed_deps = Option.value ~default:Dep.Set.empty needed_deps in
    { done_or_more_deps; needed_deps }
  ;;
end

type exec_context =
  { targets : Targets.Validated.t option
  ; context : Build_context.t option
  ; metadata : Process.metadata
  ; rule_loc : Loc.t
  ; build_deps : Dep.Set.t -> Dep.Facts.t Fiber.t
  }

type exec_environment =
  { working_dir : Path.t
  ; env : Env.t
  ; stdout_to : Process.Io.output Process.Io.t
  ; stderr_to : Process.Io.output Process.Io.t
  ; stdin_from : Process.Io.input Process.Io.t
  ; prepared_dependencies : DAP.Dependency.Set.t
  ; exit_codes : int Predicate.t
  }

>>>>>>> 3b285a94d (Add Order_only dep specification + and action needed_deps)
open Produce.O

let exec_run ~display ~(ectx : context) ~(eenv : env) prog args : _ Produce.t =
  let* (res : (Proc.Times.t, int) result) =
    Produce.of_fiber
    @@ Process.run_with_times
         ~display
         (Accept eenv.exit_codes)
         ~dir:eenv.working_dir
         ~env:eenv.env
         ~stdout_to:eenv.stdout_to
         ~stderr_to:eenv.stderr_to
         ~stdin_from:eenv.stdin_from
         ~metadata:ectx.metadata
         prog
         args
  in
  match res with
  | Error _ -> Produce.return ()
  | Ok times -> Produce.incr_duration times.elapsed_time
;;

<<<<<<< HEAD
=======
let exec_run_dynamic_client ~display ~ectx ~eenv prog args =
  let run_arguments_fn = Temp.create File ~prefix:"dune" ~suffix:"run" in
  let response_fn = Temp.create File ~prefix:"dune" ~suffix:"response" in
  let run_arguments =
    let targets =
      match ectx.targets with
      | None -> String.Set.empty
      | Some targets ->
        if not (Filename.Set.is_empty targets.dirs)
        then
          User_error.raise
            ~loc:ectx.rule_loc
            [ Pp.text "Directory targets are not compatible with dynamic actions" ];
        Filename.Set.to_list_map targets.files ~f:(fun target ->
          Path.Build.relative targets.root target
          |> Path.build
          |> Path.reach ~from:eenv.working_dir)
        |> String.Set.of_list
    in
    { DAP.Run_arguments.prepared_dependencies = eenv.prepared_dependencies; targets }
  in
  DAP.Run_arguments.to_sexp run_arguments
  |> Csexp.to_string
  |> Io.write_file run_arguments_fn;
  let env =
    let value =
      DAP.Greeting.(
        to_sexp
          { run_arguments_fn = Path.to_absolute_filename run_arguments_fn
          ; response_fn = Path.to_absolute_filename response_fn
          })
      |> Csexp.to_string
    in
    Env.add eenv.env ~var:DAP.run_by_dune_env_variable ~value
  in
  let+ () =
    Produce.of_fiber
    @@ Process.run
         ~display
         Strict
         ~dir:eenv.working_dir
         ~env
         ~stderr_to:eenv.stderr_to
         ~stdin_from:eenv.stdin_from
         ~metadata:ectx.metadata
         prog
         args
  in
  let response_raw = Io.read_file response_fn in
  Temp.destroy File run_arguments_fn;
  Temp.destroy File response_fn;
  let response =
    match Csexp.parse_string response_raw with
    | Ok s -> DAP.Response.of_sexp s
    | Error _ -> Error DAP.Error.Parse_error
  in
  let prog_name = Path.reach ~from:eenv.working_dir prog in
  match response with
  | Error _ when String.is_empty response_raw ->
    User_error.raise
      ~loc:ectx.rule_loc
      [ Pp.textf
          "Executable '%s' declared as using dune-action-plugin (declared with \
           'dynamic-run' tag) failed to respond to dune."
          prog_name
      ; Pp.nop
      ; Pp.text
          "If you don't use dynamic dependency discovery in your executable you may \
           consider changing 'dynamic-run' to 'run' in your rule definition."
      ]
  | Error Parse_error ->
    User_error.raise
      ~loc:ectx.rule_loc
      [ Pp.textf
          "Executable '%s' declared as using dune-action-plugin (declared with \
           'dynamic-run' tag) responded with invalid message."
          prog_name
      ]
  | Error (Version_mismatch _) ->
    User_error.raise
      ~loc:ectx.rule_loc
      [ Pp.textf
          "Executable '%s' is linked against a version of dune-action-plugin library \
           that is incompatible with this version of dune."
          prog_name
      ]
  | Ok Done -> Action_res.return Done
  | Ok (Need_more_deps deps) ->
    let done_or_more_deps =
      Need_more_deps
        ( deps
        , Action_plugin.to_dune_dep_set
            deps
            ~loc:ectx.rule_loc
            ~working_dir:eenv.working_dir )
    in
    Action_res.return done_or_more_deps
;;

>>>>>>> 3b285a94d (Add Order_only dep specification + and action needed_deps)
let exec_echo stdout_to str =
  Produce.return @@ output_string (Process.Io.out_channel stdout_to) str
;;

let bash_exn =
  let bin = lazy (Bin.which ~path:(Env_path.path Env.initial) "bash") in
  fun ~loc ~needed_to ->
    match Lazy.force bin with
    | Some path -> path
    | None ->
      User_error.raise
        ~loc
        [ Pp.textf "I need bash to %s but I couldn't find it :(" needed_to ]
;;

let zero = Predicate_lang.element 0
let maybe_async f = Produce.of_fiber (maybe_async f)

let rec exec t ~display ~ectx ~eenv : Action_res.t Produce.t =
  match (t : Action.t) with
  | Run (Error e, _) -> Action.Prog.Not_found.raise e
  | Run (Ok prog, args) ->
    let+ () = exec_run ~display ~ectx ~eenv prog (Array.Immutable.to_list args) in
    Action_res.return Done
  | With_accepted_exit_codes (exit_codes, t) ->
    let eenv =
      let exit_codes =
        Predicate.create (Predicate_lang.test exit_codes ~test:Int.equal ~standard:zero)
      in
      { eenv with exit_codes }
    in
    exec t ~display ~ectx ~eenv
  | Dynamic_run (Error e, _) -> Action.Prog.Not_found.raise e
  | Dynamic_run (Ok prog, args) ->
    Produce.of_fiber (Action_plugin.exec ~display ~ectx ~eenv prog args)
  | Chdir (dir, t) -> exec t ~display ~ectx ~eenv:{ eenv with working_dir = dir }
  | Setenv (var, value, t) ->
    exec t ~display ~ectx ~eenv:{ eenv with env = Env.add eenv.env ~var ~value }
  | Redirect_out (Stdout, fn, perm, Echo s) ->
    let perm = Action.File_perm.to_unix_perm perm in
    let+ () =
      maybe_async (fun () ->
        Io.write_file (Path.build fn) (String.concat s ~sep:" ") ~perm)
    in
    Action_res.return Done
  | Redirect_out (outputs, fn, perm, t) ->
    let fn = Path.build fn in
    redirect_out t ~display ~ectx ~eenv outputs ~perm fn
  | Redirect_in (inputs, fn, t) -> redirect_in t ~display ~ectx ~eenv inputs fn
  | Ignore (outputs, t) ->
    redirect_out t ~display ~ectx ~eenv ~perm:Normal outputs Dev_null.path
  | Progn ts -> exec_list ts ~display ~ectx ~eenv
  | Concurrent ts ->
    Produce.parallel_map ts ~f:(exec ~display ~ectx ~eenv)
    >>| List.fold_left ~f:Action_res.union ~init:(Action_res.return Done)
  | Echo strs ->
    let+ () = exec_echo eenv.stdout_to (String.concat strs ~sep:" ") in
    Action_res.return Done
  | Cat xs ->
    let+ () =
      maybe_async (fun () ->
        List.iter xs ~f:(fun fn ->
          Io.with_file_in fn ~f:(fun ic ->
            Io.copy_channels ic (Process.Io.out_channel eenv.stdout_to))))
    in
    Action_res.return Done
  | Copy (src, dst) ->
    let dst = Path.build dst in
    let+ () = maybe_async (fun () -> Io.copy_file ~src ~dst ()) in
    Action_res.return Done
  | Symlink (src, dst) ->
    let+ () = maybe_async (fun () -> Io.portable_symlink ~src ~dst:(Path.build dst)) in
    Action_res.return Done
  | Hardlink (src, dst) ->
    let+ () = maybe_async (fun () -> Io.portable_hardlink ~src ~dst:(Path.build dst)) in
<<<<<<< HEAD
    Done
=======
    Action_res.return Done
  | System cmd ->
    let path, arg = Utils.system_shell_exn ~needed_to:"interpret (system ...) actions" in
    let+ () = exec_run ~display ~ectx ~eenv path [ arg; cmd ] in
    Action_res.return Done
>>>>>>> 3b285a94d (Add Order_only dep specification + and action needed_deps)
  | Bash cmd ->
    let+ () =
      exec_run
        ~display
        ~ectx
        ~eenv
        (bash_exn ~loc:ectx.rule_loc ~needed_to:"interpret (bash ...) actions")
        [ "-e"; "-u"; "-o"; "pipefail"; "-c"; cmd ]
    in
    Action_res.return Done
  | Write_file (fn, perm, s) ->
    let perm = Action.File_perm.to_unix_perm perm in
    let+ () = maybe_async (fun () -> Io.write_file (Path.build fn) s ~perm) in
    Action_res.return Done
  | Rename (src, dst) ->
    let src = Path.Build.to_string src in
    let dst = Path.Build.to_string dst in
    let+ () = maybe_async (fun () -> Unix.rename src dst) in
    Action_res.return Done
  | Remove_tree path ->
    let+ () = maybe_async (fun () -> Path.rm_rf (Path.build path)) in
    Action_res.return Done
  | Mkdir path ->
    let+ () = maybe_async (fun () -> Path.mkdir_p (Path.build path)) in
<<<<<<< HEAD
    Done
  | Pipe (outputs, l) -> exec_pipe ~display ~ectx ~eenv outputs l
  | Extension (module A) ->
    let+ () = Produce.of_fiber @@ A.Spec.action A.v ~ectx ~eenv in
    Done
=======
    Action_res.return Done
  | Diff ({ optional; file1; file2; mode } as diff) ->
    let remove_intermediate_file () =
      if optional
      then (
        try Path.unlink_exn (Path.build file2) with
        | Unix.Unix_error (ENOENT, _, _) -> ())
    in
    if diff_eq_files diff
    then (
      remove_intermediate_file ();
      Produce.return (Action_res.return Done))
    else (
      let is_copied_from_source_tree file =
        match Path.extract_build_context_dir_maybe_sandboxed file with
        | None -> false
        | Some (_, file) -> Path.Untracked.exists (Path.source file)
      in
      let+ () =
        let in_source_or_target =
          is_copied_from_source_tree file1 || not (Path.Untracked.exists file1)
        in
        let source_file =
          snd (Option.value_exn (Path.extract_build_context_dir_maybe_sandboxed file1))
        in
        Produce.of_fiber
        @@ Fiber.finalize
             (fun () ->
               let annots =
                 User_message.Annots.singleton
                   Diff_promotion.Annot.annot
                   { Diff_promotion.Annot.in_source = source_file
                   ; in_build =
                       (if optional && in_source_or_target
                        then Diff_promotion.File.in_staging_area source_file
                        else file2)
                   }
               in
               if mode = Binary
               then
                 User_error.raise
                   ~annots
                   ~loc:ectx.rule_loc
                   [ Pp.textf
                       "Files %s and %s differ."
                       (Path.to_string_maybe_quoted file1)
                       (Path.to_string_maybe_quoted (Path.build file2))
                   ]
               else
                 Print_diff.print
                   annots
                   file1
                   (Path.build file2)
                   ~skip_trailing_cr:(mode = Text && Sys.win32))
             ~finally:(fun () ->
               (match optional with
                | false ->
                  (* Promote if in the source tree or not a target. The second case
                     means that the diffing have been done with the empty file *)
                  if in_source_or_target
                     && not (is_copied_from_source_tree (Path.build file2))
                  then
                    Diff_promotion.File.register_dep ~source_file ~correction_file:file2
                | true ->
                  if in_source_or_target
                  then
                    Diff_promotion.File.register_intermediate
                      ~source_file
                      ~correction_file:file2
                  else remove_intermediate_file ());
               Fiber.return ())
      in
      Action_res.return Done)
  | Pipe (outputs, l) -> exec_pipe ~display ~ectx ~eenv outputs l
  | Extension (module A) ->
    let+ () =
      Produce.of_fiber
      @@ A.Spec.action A.v ~ectx:(restrict_ctx ectx) ~eenv:(restrict_env eenv)
    in
    Action_res.return Done
  | Needed_deps needed ->
    let ds = Dune_sexp.Decoder.repeat (Dep.decode eenv.working_dir) in
    let parsed_sexp = List.concat_map needed ~f:(Dune_sexp.Parser.load ~mode:Many) in
    let deps = List.map parsed_sexp ~f:(Dune_sexp.Decoder.parse ds Univ_map.empty) in
    let needed_deps = Dep.Set.of_list (List.concat deps) in
    Produce.return (Action_res.return ~needed_deps Done)
>>>>>>> 3b285a94d (Add Order_only dep specification + and action needed_deps)

and redirect_out t ~display ~ectx ~eenv ~perm outputs fn =
  redirect t ~display ~ectx ~eenv ~out:(outputs, fn, perm) ()

and redirect_in t ~display ~ectx ~eenv inputs fn =
  redirect t ~display ~ectx ~eenv ~in_:(inputs, fn) ()

and redirect t ~display ~ectx ~eenv ?in_ ?out () =
  let stdin_from, release_in =
    match in_ with
    | None -> eenv.stdin_from, ignore
    | Some (Stdin, fn) ->
      let in_ = Process.Io.file fn Process.Io.In in
      in_, fun () -> Process.Io.release in_
  in
  let stdout_to, stderr_to, release_out =
    match out with
    | None -> eenv.stdout_to, eenv.stderr_to, ignore
    | Some (outputs, fn, perm) ->
      let out =
        Process.Io.file fn Process.Io.Out ~perm:(Action.File_perm.to_unix_perm perm)
      in
      let stdout_to, stderr_to =
        match outputs with
        | Stdout -> out, eenv.stderr_to
        | Stderr -> eenv.stdout_to, out
        | Outputs -> out, out
      in
      stdout_to, stderr_to, fun () -> Process.Io.release out
  in
  let+ result =
    exec t ~display ~ectx ~eenv:{ eenv with stdin_from; stdout_to; stderr_to }
  in
  release_in ();
  release_out ();
  result

and exec_list ts ~display ~ectx ~eenv : Action_res.t Produce.t =
  match ts with
  | [] -> Produce.return (Action_res.return Done ~needed_deps:Dep.Set.empty)
  | [ t ] ->
    let* action_res = exec t ~display ~ectx ~eenv in
    (match action_res with
     | { done_or_more_deps = d; needed_deps } ->
       Produce.return (Action_res.return d ~needed_deps))
  | t :: rest ->
    let* action_res =
      let stdout_to = Process.Io.multi_use eenv.stdout_to in
      let stderr_to = Process.Io.multi_use eenv.stderr_to in
      let stdin_from = Process.Io.multi_use eenv.stdin_from in
      exec t ~display ~ectx ~eenv:{ eenv with stdout_to; stderr_to; stdin_from }
    in
    (match action_res with
     | { done_or_more_deps = Need_more_deps _ as need; needed_deps } ->
       Produce.return (Action_res.return need ~needed_deps)
     | { done_or_more_deps = Done; needed_deps } ->
       let* x = exec_list rest ~display ~ectx ~eenv in
       let needed_deps = Dep.Set.union x.needed_deps needed_deps in
       Produce.return (Action_res.return Done ~needed_deps))

and exec_pipe outputs ts ~display ~ectx ~eenv : Action_res.t Produce.t =
  let tmp_file () =
    Dtemp.file ~prefix:"dune-pipe-action-" ~suffix:("." ^ Action.Outputs.to_string outputs)
  in
  let rec loop ~in_ ts =
    match ts with
    | [] -> assert false
    | [ last_t ] ->
      let eenv =
        match outputs with
        | Stderr -> { eenv with stdout_to = Process.Io.multi_use eenv.stderr_to }
        | _ -> eenv
      in
      let+ result = redirect_in last_t ~display ~ectx ~eenv Stdin in_ in
      Dtemp.destroy File in_;
      result
    | t :: ts ->
      let out = tmp_file () in
      let* action_res =
        let eenv = { eenv with stderr_to = Process.Io.multi_use eenv.stderr_to } in
        redirect t ~display ~ectx ~eenv ~in_:(Stdin, in_) ~out:(Stdout, out, Normal) ()
      in
      Dtemp.destroy File in_;
      (match action_res with
       | { done_or_more_deps = Need_more_deps _ as need; needed_deps } ->
         Produce.return (Action_res.return need ~needed_deps)
       | { done_or_more_deps = Done; needed_deps = needed } ->
         let* res = loop ~in_:out ts in
         let needed_deps = Dep.Set.union res.needed_deps needed in
         Produce.return (Action_res.return Done ~needed_deps))
  in
  match ts with
  | [] -> assert false
  | t1 :: ts ->
    let out = tmp_file () in
    let eenv =
      match outputs with
      | Outputs -> eenv
      | Stdout -> { eenv with stderr_to = Process.Io.multi_use eenv.stderr_to }
      | Stderr -> { eenv with stdout_to = Process.Io.multi_use eenv.stdout_to }
    in
    let* done_or_deps = redirect_out t1 ~display ~ectx ~eenv ~perm:Normal outputs out in
    (match done_or_deps with
     | { done_or_more_deps = Need_more_deps _ as need; needed_deps } ->
       Produce.return (Action_res.return need ~needed_deps)
     | { done_or_more_deps = Done; needed_deps = needed } ->
       let* res = loop ~in_:out ts in
       let needed_deps = Dep.Set.union res.needed_deps needed in
       Produce.return (Action_res.return Done ~needed_deps))
;;

let exec_until_all_deps_ready ~display ~ectx ~eenv t =
  let rec loop ~eenv stages =
    let* result = exec ~display ~ectx ~eenv t in
    match result with
    | { done_or_more_deps = Done; needed_deps = deps } ->
      let* fact_map = Produce.of_fiber @@ ectx.build_deps deps in
      Produce.return (stages, (deps, fact_map))
    | { done_or_more_deps = Need_more_deps (relative_deps, deps_to_build)
      ; needed_deps = _
      } ->
      let* fact_map = Produce.of_fiber @@ ectx.build_deps deps_to_build in
      let stages = (deps_to_build, fact_map) :: stages in
      let eenv =
        { eenv with
          prepared_dependencies =
            Action_plugin.Dependency.Set.union eenv.prepared_dependencies relative_deps
        }
      in
      loop ~eenv stages
  in
  let open Fiber.O in
  let+ (stages, needed_deps), state = Produce.run Produce.State.empty (loop ~eenv []) in
  { Exec_result.dynamic_deps_stages = List.rev stages
  ; duration = state.duration
  ; needed_deps
  }
;;

type input =
  { targets : Targets.Validated.t option (* Some Jane Street actions use [None] *)
  ; root : Path.t
  ; context : Build_context.t option
  ; env : Env.t
  ; rule_loc : Loc.t
  ; execution_parameters : Execution_parameters.t
  ; action : Action.t
  }

let exec
  { targets; root; context; env; rule_loc; execution_parameters; action = t }
  ~build_deps
  =
  let ectx =
    let metadata = Process.create_metadata ~purpose:(Build_job targets) () in
    { targets; metadata; context; rule_loc; build_deps }
  and eenv =
    let env =
      match
        Execution_parameters.workspace_root_to_build_path_prefix_map execution_parameters
      with
      | Unset -> env
      | Set target ->
        Dune_util.Build_path_prefix_map.extend_build_path_prefix_map
          env
          `New_rules_have_precedence
          (* TODO generify *)
          [ Some { source = Path.to_absolute_filename root; target } ]
    in
    { working_dir = Path.root
    ; env
    ; stdout_to =
        Process.Io.make_stdout
          ~output_on_success:
            (Execution_parameters.action_stdout_on_success execution_parameters)
          ~output_limit:(Execution_parameters.action_stdout_limit execution_parameters)
    ; stderr_to =
        Process.Io.make_stderr
          ~output_on_success:
            (Execution_parameters.action_stderr_on_success execution_parameters)
          ~output_limit:(Execution_parameters.action_stderr_limit execution_parameters)
    ; stdin_from = Process.Io.null In
    ; prepared_dependencies = Action_plugin.Dependency.Set.empty
    ; exit_codes = Predicate.create (Int.equal 0)
    }
  in
  let open Fiber.O in
  let+ result =
    Fiber.collect_errors (fun () ->
      exec_until_all_deps_ready t ~display:!Clflags.display ~ectx ~eenv)
  in
  match result with
  | Ok res -> Ok res
  | Error exns ->
    Error
      (List.map exns ~f:(fun (e : Exn_with_backtrace.t) -> Exec_result.Error.of_exn e.exn))
;;
