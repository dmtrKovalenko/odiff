let now = (name: string) => (name, ref(Unix.gettimeofday()));

let cycle = ((name, timepoint), ~cycleName="", ()) => {
  Printf.printf(
    "'%s %s' executed for: %f ms \n",
    name,
    cycleName,
    (Unix.gettimeofday() -. timepoint^) *. 1000.,
  );

  timepoint := Unix.gettimeofday()
};

let ifTimeMore = (amount, (name, timepoint)) => {
  (Unix.gettimeofday() -. timepoint) *. 1000. > amount;
};

let cycleIf = (point, predicate) =>
  if (predicate(point)) {
    cycle(point, ());
  };