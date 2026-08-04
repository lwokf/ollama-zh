#!/usr/bin/env node
/**
 * Apply the zh-CN translation dictionary to a pristine Ollama source tree.
 *
 * Usage:
 *   node tools/translate.mjs <source-dir> <output-dir>
 *
 * Matching is exact-literal based so it is safe against substring corruption:
 *   - "KEY" (double-quoted string literal, JS/TS/Go)
 *   - 'KEY' (single-quoted string literal)
 *   - `KEY` (template literal)
 *   - >KEY< (JSX text node)
 */
import fs from "node:fs";
import path from "node:path";

const dictPath = path.join(import.meta.dirname, "..", "translations", "zh-CN.json");
const dict = JSON.parse(fs.readFileSync(dictPath, "utf8"));

const [src, dst] = process.argv.slice(2);
if (!src || !dst) {
  console.error("usage: node tools/translate.mjs <source-dir> <output-dir>");
  process.exit(1);
}

function esc(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Build replacement patterns per key: full-literal matches only.
const rules = [];
for (const [en, zh] of Object.entries(dict)) {
  const e = esc(en);
  rules.push([new RegExp(`"${e}"`, "g"), `"${zh}"`]);
  rules.push([new RegExp(`'${e}'`, "g"), `'${zh}'`]);
  rules.push([new RegExp("`" + e + "`", "g"), "`" + zh + "`"]);
  rules.push([new RegExp(`>\\s*${e}\\s*<`, "g"), `>${zh}<`]);
}

// Special-case rules that cannot be expressed as exact literals in the dictionary
// (multi-line JSX text, template literals with interpolation, JSX fragments).
const specialRules = [
  // Settings -> Context length description (JSX text spans multiple source lines)
  [
    />Context\s+length\s+determines\s+how\s+much\s+of\s+your\s+conversation[\s\S]*?local\s+LLMs\s+can\s+remember\s+and\s+use\s+to\s+generate\s+responses\.\s*</g,
    ">上下文长度决定了本地大模型能记住并使用多少对话内容来生成回复。</",
  ],
  // Thinking.tsx -> interpolated "Thought for X seconds" template literal
  [/`Thought for \$\{thinkingTime\.toFixed\(1\)\} seconds`/g, "`思考了 ${thinkingTime.toFixed(1)} 秒`"],
  // Message.tsx -> "Search results for <InlineSearchTerm .../>" JSX fragment
  [/Search results for /g, "搜索结果: "],
];

// Directories under upstream that hold user-facing UI strings.
const SCOPE = ["app/ui/app/src", "app/wintray", "app/cmd", "app/ui/ui.go", "app/ui/app.go"];

let replaced = 0;

function walk(dir, rel = "") {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const relPath = rel ? `${rel}/${entry.name}` : entry.name;
    const abs = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === ".git" || entry.name === "node_modules" || entry.name === "dist") continue;
      fs.mkdirSync(abs.replace(src, dst), { recursive: true });
      walk(abs, relPath);
    } else {
      const outAbs = abs.replace(src, dst);
      fs.mkdirSync(path.dirname(outAbs), { recursive: true });
      let content = fs.readFileSync(abs);
      const inScope = SCOPE.some((s) => relPath === s || relPath.startsWith(s + "/") || relPath.endsWith(s));
      if (inScope) {
        let text = content.toString("utf8");
        let before = text;
        for (const [re, zh] of rules) {
          text = text.replace(re, zh);
        }
        for (const [re, zh] of specialRules) {
          text = text.replace(re, zh);
        }
        if (text !== before) {
          replaced += countDiff(before, text);
        }
        content = Buffer.from(text, "utf8");
      }
      fs.writeFileSync(outAbs, content);
    }
  }
}

function countDiff(a, b) {
  const countA = (s) => (s.match(/[\u4e00-\u9fff]/g) || []).length;
  return Math.abs(countA(b) - countA(a));
}

if (!fs.existsSync(src)) {
  console.error(`source dir not found: ${src}`);
  process.exit(1);
}
const srcResolved = path.resolve(src);
const dstResolved = path.resolve(dst);
if (srcResolved !== dstResolved) {
  fs.rmSync(dst, { recursive: true, force: true });
  fs.mkdirSync(dst, { recursive: true });
}
walk(src);
console.log(`translated tree written to ${dst}`);
