const fs = require("fs");
const path = require("path");

const readmePath = path.resolve(__dirname, "..", "README.md");
const currentReadmeContent = fs.readFileSync(readmePath, {
  encoding: "utf-8",
});

const START_COMMENT = "<!--inline-interface-start-->";
const END_COMMENT = "<!--inline-interface-end-->";

const [startOfFile, afterStartMark] = currentReadmeContent.split(START_COMMENT);
const [_, endOfFile] = afterStartMark.split(END_COMMENT);

const tsInterface = fs.readFileSync(
  path.resolve(__dirname, "..", "npm_package", "odiff.d.ts"),
  {
    encoding: "utf-8",
  },
);

const updatedReadme = [
  startOfFile,
  START_COMMENT,
  "\n```tsx\n",
  tsInterface,
  "```\n",
  END_COMMENT,
  endOfFile,
].join("");

console.log(process.argv[2]);
if (process.argv[2] === "verify") {
  if (updatedReadme !== currentReadmeContent) {
    throw new Error(
      "❌ Outdated README detected. Run `node scripts/process-readme.js` and repush your branch",
    );
  } else {
    console.log("✅ README is up-to-date");
  }
} else {
  fs.writeFileSync(readmePath, updatedReadme);
}
