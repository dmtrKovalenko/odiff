include Rely.Make (struct
  let config =
    Rely.TestFrameworkConfig.initialize
      { snapshotDir = "test/__snapshots__"; projectDir = "." }
end)
