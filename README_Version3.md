# CodeFixer

**CodeFixer** is a next-generation, multi-language, parallel, and safe code fixer/formatter—a single Bash script that automatically finds and fixes code issues across Python, JS/TS, Shell, Go, Rust, C++, YAML, JSON, and more.

---

## 🚀 Features

- **Multi-language:** Python, JS/TS, Shell, Go, Rust, C++, YAML, JSON, Markdown, CSS, Ruby, Java
- **Smart Auto-Fix:** Applies best-in-class formatters/linters (black, eslint, gofmt, rustfmt, clang-format, prettier, etc.)
- **Parallel Processing:** Fast, safe analysis, scalable to large codebases
- **Backups:** Original files backed up before changes (unless disabled)
- **Configurable:** Simple `config.yaml` for ignores, tool overrides, and settings
- **Beautiful Reports:** Markdown and JSON summaries by file and language
- **CI & Pre-commit Ready:** Works in pipelines or as a pre-commit hook
- **No vendor lock-in:** 100% open, extensible, hackable Bash

---

## ⚡ Quickstart

1. **Install dependencies:**  
   Use the provided `install.sh` or manually install required formatters/linters for your languages.

2. **Run CodeFixer:**

   ```sh
   ./codefixer.sh --fix .
   ```

   - Analyze and auto-fix all supported files in your project.
   - Backups are made in `~/.codefixer/backups`.
   - Reports saved to `~/.codefixer/logs/report.md` and `report.json`.

3. **See all options:**

   ```sh
   ./codefixer.sh --help
   ```

---

## 🔧 Example `config.yaml`

```yaml
depth: 3
fix: true
ignore:
  - "node_modules/"
  - "*.min.js"
  - "vendor/"
  - "*.lock"
tool_python: "poetry run black"
tool_javascript: "./node_modules/.bin/eslint"
```

- `depth`: Max directory depth to search (default: 5)
- `fix`: Enable auto-fix by default (or use `--fix` flag)
- `ignore`: List of file globs or directories to skip
- `tool_{lang}`: Use a custom command for a language (e.g., run black via poetry, or use a local eslint)

---

## 🛠️ Advanced Usage

- **Dry run (no changes):**
  ```sh
  ./codefixer.sh --dry-run .
  ```
- **Parallel jobs:**
  ```sh
  ./codefixer.sh --fix -j 8 .
  ```
- **Prompt before each fix:**
  ```sh
  ./codefixer.sh --fix --prompt .
  ```
- **Generate reports only:**
  ```sh
  ./codefixer.sh --report .
  ```
- **Restrict to git-tracked files:**
  ```sh
  ./codefixer.sh --git-only .
  ```

---

## 💡 YAML Config Notes

- Only supports simple keys: `depth:`, `fix:`, top-level `ignore:` array, and `tool_{lang}` overrides.
- Inline comments and nested YAML structures are **not** supported.
- For advanced config, [edit the script](./codefixer.sh) or open a PR!

---

## 🧠 How it Works

- Finds all files matching patterns for each language (or just git-tracked files with `--git-only`)
- Runs static analysis and (optionally) auto-fix tools **in parallel**
- Makes safe backups before any changes
- Generates rich Markdown and JSON reports

---

## 🫶 Contributing

- Want to add a language? Open a PR or fork!
- Found a bug? [File an issue](https://github.com/yourrepo/yourproject/issues)
- Want to discuss new features? Open a discussion!

---

## License

MIT
