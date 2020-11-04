exception ImageNotLoaded;

let loadImage = filename => {
  switch (Images.load(filename, [])) {
  | Index8(i8img) => Index8.to_rgba32(i8img)
  | Rgb24(rgba24img) => Rgb24.to_rgba32(rgba24img)
  | Rgba32(img) => img
  | imgTyp => raise(ImageNotLoaded)
  };
};