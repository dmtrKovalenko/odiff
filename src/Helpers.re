let isSameColor = (a, b) => {
  let (base_r, base_g, base_b, base_a) = a;
  let (comp_r, comp_g, comp_b, comp_a) = b;

  base_r == comp_r && base_g == comp_g && base_b == comp_b && base_a == comp_a;
};
