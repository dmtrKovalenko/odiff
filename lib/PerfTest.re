let now = (name: string) => (name, Unix.gettimeofday());

let cycle = ((name, timepoint)) => {
  Printf.printf(
    "'%s' executed for: %f ms \n",
    name,
    (Unix.gettimeofday() -. timepoint) *. 1000.,
  );
};