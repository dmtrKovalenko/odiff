include Rely.Make({
  let config =
    Rely.TestFrameworkConfig.initialize({
      snapshotDir: "test/__snapshots__",
      projectDir: "."
    });
});