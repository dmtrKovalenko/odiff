type 'a contents =
  | Empty of {receivers: ('a option ref * Domain.id) Fun_queue.t}
  | NotEmpty of {senders: ('a * Domain.id) Fun_queue.t; messages: 'a Fun_queue.t}

type 'a t = {buffer_size: int option; contents: 'a contents Atomic.t}

let make_bounded n =
  if n < 0 then raise (Invalid_argument "Chan.make_bounded") ;
  {buffer_size= Some n; contents = Atomic.make (Empty {receivers= Fun_queue.empty})}

let make_unbounded () =
  {buffer_size= None; contents = Atomic.make (Empty {receivers= Fun_queue.empty})}

(* [send'] is shared by both the blocking and polling versions. Returns a
 * boolean indicating whether the send was successful. Hence, it always returns
 * [true] if [polling] is [false]. *)
let send' {buffer_size; contents} v ~polling =
  let open Fun_queue in
  let rec loop () =
    let old_contents = Atomic.get contents in
    match old_contents with
    | Empty {receivers} -> begin
      (* The channel is empty (no senders) *)
      match pop receivers with
      | None ->
          (* The channel is empty (no senders) and no waiting receivers *)
          if buffer_size = Some 0 then
            (* The channel is empty (no senders), no waiting receivers, and
              * buffer size is 0 *)
            begin if not polling then begin
              (* The channel is empty (no senders), no waiting receivers,
                * buffer size is 0 and we're not polling *)
              let new_contents =
                NotEmpty
                  {messages= empty; senders= push empty (v, Domain.self ())}
              in
              if Atomic.compare_and_set contents old_contents new_contents
              then (Domain.Sync.wait (); true)
              else loop ()
            end else
              (* The channel is empty (no senders), no waiting receivers,
                * buffer size is 0 and we're polling *)
              false
            end
          else
            (* The channel is empty (no senders), no waiting receivers, and
              * the buffer size is non-zero *)
            let new_contents =
              NotEmpty {messages= push empty v; senders= empty}
            in
            if Atomic.compare_and_set contents old_contents new_contents
            then true
            else loop ()
      | Some ((r, d), receivers') ->
          (* The channel is empty (no senders) and there are waiting receivers
           * *)
          let new_contents = Empty {receivers= receivers'} in
          if Atomic.compare_and_set contents old_contents new_contents
          then (
            r := Some v;
           (* Notifying another domain from within a critical section is unsafe
            * in general. Notify blocks until the target domain is out of the
            * critical section. If two domains are notifying each other from
            * within critical section, then the program deadlocks. However,
            * here (and other uses of notify in send' and recv' in the channel
            * implementation), there is no possibility of other domains
            * notifying this domain; only a blocked domain will be notified,
            * and this domain is currently running. Hence, it is ok to notify
            * from within the critical section. *)
            Domain.Sync.notify d;
            true )
          else loop ()
    end
    | NotEmpty {senders; messages} ->
        (* The channel is not empty *)
        if buffer_size = Some (length messages) then
          (* The channel is not empty, and the buffer is full *)
          begin if not polling then
            (* The channel is not empty, the buffer is full and we're not
              * polling *)
            let new_contents =
              NotEmpty {senders= push senders (v, Domain.self ()); messages}
            in
            if Atomic.compare_and_set contents old_contents new_contents then
              ( Domain.Sync.wait () ; true )
            else loop ()
          else
            (* The channel is not empty, the buffer is full and we're
              * polling *)
            false
          end
        else
          (* The channel is not empty, and the buffer is not full *)
          let new_contents =
            NotEmpty {messages= push messages v; senders}
          in
          if Atomic.compare_and_set contents old_contents new_contents
          then true
          else loop ()
  in
  Domain.Sync.critical_section loop

let send c v =
  let r = send' c v ~polling:false in
  assert r

let send_poll c v = send' c v ~polling:true

(* [recv'] is shared by both the blocking and polling versions. Returns a an
 * optional value indicating whether the receive was successful. Hence, it
 * always returns [Some v] if [polling] is [false]. *)
let recv' {buffer_size; contents} ~polling =
  let open Fun_queue in
  let rec loop () =
    let old_contents = Atomic.get contents in
    match old_contents with
    | Empty {receivers} ->
        (* The channel is empty (no senders) *)
        if not polling then begin
          (* The channel is empty (no senders), and we're not polling *)
          let msg_slot = ref None in
          let new_contents =
            Empty {receivers= push receivers (msg_slot, Domain.self ())}
          in
          if Atomic.compare_and_set contents old_contents new_contents then
            (Domain.Sync.wait (); !msg_slot)
          else loop ()
        end else
          (* The channel is empty (no senders), and we're polling *)
          None
    | NotEmpty {senders; messages} ->
        (* The channel is not empty *)
        match (pop messages, pop senders) with
        | None, None ->
            (* The channel is not empty, but no senders or messages *)
            failwith "Chan.recv: Impossible - channel state"
        | Some (m, messages'), None ->
            (* The channel is not empty, there is a message and no
              * waiting senders *)
            let new_contents =
              if length messages' = 0 then
                Empty {receivers = empty}
              else
                NotEmpty {messages= messages'; senders}
            in
            if Atomic.compare_and_set contents old_contents new_contents
            then Some m
            else loop ()
        | None, Some ((m, s), senders') ->
            (* The channel is not empty, there are no messages, and there
              * is a waiting sender. This is only possible is the buffer
              * size is 0. *)
            assert (buffer_size = Some 0) ;
            let new_contents =
              if length senders' = 0 then
                Empty {receivers = empty}
              else
                NotEmpty {messages; senders= senders'}
            in
            if Atomic.compare_and_set contents old_contents new_contents
            then (Domain.Sync.notify s; Some m)
            else loop ()
        | Some (m, messages'), Some ((ms, s), senders') ->
            (* The channel is not empty, there is a message, and there is a
              * waiting sender. *)
            let new_contents =
              NotEmpty {messages= push messages' ms; senders= senders'}
            in
            if Atomic.compare_and_set contents old_contents new_contents
            then (Domain.Sync.notify s; Some m)
            else loop ()
  in
  Domain.Sync.critical_section loop

let recv c =
  match recv' c ~polling:false with
  | None -> failwith "Chan.recv: impossible - no message"
  | Some m -> m

let recv_poll c =
  match Atomic.get c.contents with
  | Empty _ -> None
  | _ -> recv' c ~polling:true
