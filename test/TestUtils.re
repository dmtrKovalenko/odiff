let getFileContents = filename => {
  let ic = open_in_bin(filename);
  let file_length = in_channel_length(ic);
  let data = really_input_string(ic, file_length);
  close_in(ic);
  data;
};
