#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

import { parse as parseYaml, parseAllDocuments } from "yaml";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS_DIR = join(ROOT, "skills");
const ROOT_README = join(ROOT, "README.md");
const CANONICAL_BENCH = join(
  SKILLS_DIR,
  "self-hosted-llms",
  "scripts",
  "bench.sh",
);
const KEBAB_NAME = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const TEMPLATE_NAMES = new Set(["my-skill"]);
const REQUIRED_FILES = ["SKILL.md", "README.md", "metadata.json"];
const METADATA_KEYS = [
  "version",
  "organization",
  "date",
  "abstract",
  "references",
];
const MAX_NAME_LENGTH = 64;
const MAX_DESCRIPTION_LENGTH = 1024;
const MAX_COMPATIBILITY_LENGTH = 500;
const MAX_SKILL_LINES = 300;
const MARKDOWN_LINK = /\[[^\]]*\]\(([^)\s]+)\)/g;
const VERIFIED_LINE = /^> Verified against .+, \d{4}-\d{2}-\d{2}$/;
const IGNORED_DIRS = new Set([".git", "node_modules"]);

function walk(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    if (IGNORED_DIRS.has(entry.name)) return [];
    const path = join(dir, entry.name);
    return entry.isDirectory() ? walk(path) : [path];
  });
}

function parseFrontmatter(content) {
  const match = content.match(
    /^---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(\r?\n|$)/,
  );
  if (!match)
    return {
      error:
        "SKILL.md has no frontmatter block (expected --- ... --- at the top)",
    };
  try {
    const fields = parseYaml(match[1]);
    if (
      typeof fields !== "object" ||
      fields === null ||
      Array.isArray(fields)
    ) {
      return { error: "SKILL.md frontmatter is not a mapping" };
    }
    return { fields };
  } catch (error) {
    return {
      error: `SKILL.md frontmatter YAML error: ${error.message.split("\n")[0]}`,
    };
  }
}

function brokenRelativeLinks(file) {
  const broken = [];
  for (const [, target] of readFileSync(file, "utf8").matchAll(MARKDOWN_LINK)) {
    if (/^([a-z]+:|#)/i.test(target)) continue;
    const path = decodeURI(target.split("#")[0]);
    if (!existsSync(join(dirname(file), path))) broken.push(target);
  }
  return broken;
}

function validateFrontmatter(folder, fields, rootReadme) {
  const errors = [];
  const { name, description, license, metadata, compatibility } = fields;

  if (typeof name !== "string" || !name) {
    errors.push("frontmatter is missing `name`");
  } else {
    if (!KEBAB_NAME.test(name))
      errors.push(`name "${name}" must be kebab-case`);
    if (name.length > MAX_NAME_LENGTH) {
      errors.push(`name is ${name.length} characters (max ${MAX_NAME_LENGTH})`);
    }
    if (name !== folder)
      errors.push(`name "${name}" does not match folder "${folder}"`);
    if (TEMPLATE_NAMES.has(name)) {
      errors.push(
        `name "${name}" is the template placeholder; rename the skill`,
      );
    }
    if (!rootReadme.includes(`\`${name}\``)) {
      errors.push(`README.md skills table does not list \`${name}\``);
    }
  }

  if (typeof description !== "string" || !description.trim()) {
    errors.push("frontmatter is missing `description`");
  } else if (description.length > MAX_DESCRIPTION_LENGTH) {
    errors.push(
      `description is ${description.length} characters (max ${MAX_DESCRIPTION_LENGTH})`,
    );
  }

  if (license !== "MIT")
    errors.push(`license must be MIT (got ${JSON.stringify(license)})`);

  if (typeof metadata !== "object" || metadata === null) {
    errors.push("frontmatter is missing the `metadata` mapping");
  } else {
    if (!Object.values(metadata).every((value) => typeof value === "string")) {
      errors.push("every metadata value must be a string (quote versions)");
    }
    for (const key of ["author", "version"]) {
      if (typeof metadata[key] !== "string" || !metadata[key]) {
        errors.push(`metadata.${key} must be a non-empty string`);
      }
    }
  }

  if (compatibility !== undefined) {
    if (typeof compatibility !== "string") {
      errors.push("compatibility must be a string");
    } else if (compatibility.length > MAX_COMPATIBILITY_LENGTH) {
      errors.push(
        `compatibility is ${compatibility.length} characters (max ${MAX_COMPATIBILITY_LENGTH})`,
      );
    }
  }
  return errors;
}

function validateMetadataJson(skillDir, frontmatterVersion) {
  let json;
  try {
    json = JSON.parse(readFileSync(join(skillDir, "metadata.json"), "utf8"));
  } catch (error) {
    return [`metadata.json is not valid JSON: ${error.message}`];
  }
  if (typeof json !== "object" || json === null || Array.isArray(json)) {
    return ["metadata.json is not a JSON object"];
  }
  const errors = [];
  const missing = METADATA_KEYS.filter((key) => !(key in json));
  if (missing.length > 0)
    errors.push(`metadata.json is missing ${missing.join(", ")}`);
  if (json.version !== frontmatterVersion) {
    errors.push(
      `metadata.json version "${json.version}" does not match SKILL.md metadata.version "${frontmatterVersion}"`,
    );
  }
  return errors;
}

function validateReferenceHeaders(skillDir) {
  const errors = [];
  const referencesDir = join(skillDir, "references");
  if (!existsSync(referencesDir)) return errors;
  for (const entry of readdirSync(referencesDir)) {
    if (!entry.endsWith(".md")) continue;
    const lines = readFileSync(join(referencesDir, entry), "utf8")
      .split(/\r?\n/)
      .filter((line) => line.trim());
    if (!lines[0]?.startsWith("# ") || !VERIFIED_LINE.test(lines[1] ?? "")) {
      errors.push(
        `references/${entry} must start with an H1 and a "> Verified against ..., YYYY-MM-DD" line`,
      );
    }
  }
  return errors;
}

function validateFiles(skillDir) {
  const errors = [];
  for (const file of walk(skillDir)) {
    const rel = relative(skillDir, file);
    if (file.endsWith(".md")) {
      for (const target of brokenRelativeLinks(file)) {
        errors.push(`${rel} links to missing file "${target}"`);
      }
    } else if (file.endsWith(".json")) {
      try {
        JSON.parse(readFileSync(file, "utf8"));
      } catch (error) {
        errors.push(`${rel} is not valid JSON: ${error.message}`);
      }
    } else if (/\.ya?ml$/.test(file)) {
      for (const doc of parseAllDocuments(readFileSync(file, "utf8"))) {
        if (doc.errors.length > 0) {
          errors.push(
            `${rel} is not valid YAML: ${doc.errors[0].message.split("\n")[0]}`,
          );
          break;
        }
      }
    } else if (file.endsWith(".sh")) {
      try {
        execFileSync("bash", ["-n", file], { stdio: "pipe" });
      } catch (error) {
        errors.push(`${rel} fails bash -n: ${String(error.stderr).trim()}`);
      }
    }
  }
  return errors;
}

function validateSkill(folder, rootReadme) {
  const skillDir = join(SKILLS_DIR, folder);
  const errors = REQUIRED_FILES.filter(
    (file) => !existsSync(join(skillDir, file)),
  ).map((file) => `missing ${file}`);
  const skillFile = join(skillDir, "SKILL.md");

  if (existsSync(skillFile)) {
    const content = readFileSync(skillFile, "utf8");
    const lines = content.split("\n").length - (content.endsWith("\n") ? 1 : 0);
    if (lines > MAX_SKILL_LINES) {
      errors.push(`SKILL.md is ${lines} lines (max ${MAX_SKILL_LINES})`);
    }
    const { fields, error } = parseFrontmatter(content);
    if (error) {
      errors.push(error);
    } else {
      errors.push(...validateFrontmatter(folder, fields, rootReadme));
      if (existsSync(join(skillDir, "metadata.json"))) {
        errors.push(
          ...validateMetadataJson(skillDir, fields.metadata?.version),
        );
      }
    }
  }

  errors.push(...validateReferenceHeaders(skillDir));
  errors.push(...validateFiles(skillDir));
  return errors;
}

function validateRepo() {
  const errors = [];
  const pythonFiles = walk(ROOT).filter((file) => file.endsWith(".py"));
  for (const file of pythonFiles)
    errors.push(`${relative(ROOT, file)}: no Python files allowed`);

  const canonical = existsSync(CANONICAL_BENCH)
    ? readFileSync(CANONICAL_BENCH)
    : null;
  for (const file of walk(SKILLS_DIR)) {
    if (basename(file) !== "bench.sh" || file === CANONICAL_BENCH) continue;
    if (canonical === null || !readFileSync(file).equals(canonical)) {
      errors.push(
        `${relative(ROOT, file)} differs from ${relative(ROOT, CANONICAL_BENCH)}`,
      );
    }
  }
  return errors;
}

const rootReadme = existsSync(ROOT_README)
  ? readFileSync(ROOT_README, "utf8")
  : "";

const folders = existsSync(SKILLS_DIR)
  ? readdirSync(SKILLS_DIR, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
      .map((entry) => entry.name)
      .sort()
  : [];

let failed = 0;
function report(label, errors) {
  if (errors.length === 0) {
    console.log(`ok    ${label}`);
    return;
  }
  failed++;
  console.error(`FAIL  ${label}`);
  for (const error of errors) console.error(`      - ${error}`);
}

report("repo", validateRepo());
for (const folder of folders) {
  report(
    relative(ROOT, join(SKILLS_DIR, folder)),
    validateSkill(folder, rootReadme),
  );
}

if (folders.length === 0) console.log("No skills found in skills/.");

if (failed > 0) {
  console.error(`\n${failed} check group(s) failed validation.`);
  process.exit(1);
}

console.log(`\nValidated ${folders.length} skill(s).`);
