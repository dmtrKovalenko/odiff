let now = (name: string) => (name, Unix.gettimeofday());

let cycle = ((name, timepoint)) => {
  Printf.printf(
    "'%s' executed for: %f ms \n",
    name,
    (Unix.gettimeofday() -. timepoint) *. 1000.,
  );
};

let ifTimeMore = (amount, (name, timepoint)) => {
  (Unix.gettimeofday() -. timepoint) *. 1000. > amount;
};

let cycleIf = (point, predicate) =>
  if (predicate(point)) {
    cycle(point);
  };