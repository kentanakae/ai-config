# ai-config

Claude Code, Gemini CLI, Codex CLIの設定を一元管理するリポジトリ。
共通化できる設定はシンボリックリンクや参照設定で共有し、各エージェント固有の設定は個別に管理する。

## セットアップ

任意のプロジェクトにセットアップスクリプトで設定を導入できる。

```sh
# プロジェクトディレクトリでcurlから実行
cd ~/my-project
sh -c "$(curl -fsSL https://raw.githubusercontent.com/kentanakae/ai-config/main/setup-ai-config.sh)"

# 特定のエージェントのみ
sh -c "$(curl -fsSL https://raw.githubusercontent.com/kentanakae/ai-config/main/setup-ai-config.sh)" -- --claude
sh -c "$(curl -fsSL https://raw.githubusercontent.com/kentanakae/ai-config/main/setup-ai-config.sh)" -- --gemini --codex

# 設定を削除
sh -c "$(curl -fsSL https://raw.githubusercontent.com/kentanakae/ai-config/main/setup-ai-config.sh)" -- --uninstall
sh -c "$(curl -fsSL https://raw.githubusercontent.com/kentanakae/ai-config/main/setup-ai-config.sh)" -- --uninstall --claude
```

### オプション

| オプション | 説明 |
|---|---|
| `--claude` | Claude Codeの設定のみ |
| `--gemini` | Gemini CLIの設定のみ |
| `--codex` | Codex CLIの設定のみ |
| `--dir <path>` | インストール先を指定（デフォルト: カレントディレクトリ） |
| `--uninstall` | 設定を削除 |
| `--dry-run` | 実際には変更せず、実行内容を表示 |
| `--help` | ヘルプを表示 |
| 引数なし | 全エージェントの設定をセットアップ |

複数のエージェントを指定可能（例: `--claude --gemini`）。
既存ファイルがある場合は矢印キーで選択できる上書き確認プロンプトを表示する。symlinkは毎回再作成する。
cloneしたリポジトリから実行した場合は自動的に `git pull` で最新版に更新される。

## ディレクトリ構造

```
.agents/                            # 共通ベース（実体）
  rules/AGENTS.md                   # 共通ルール
  skills/                           # 共通スキル

.claude/                            # Claude Code
  CLAUDE.md                         # Claude固有設定
  rules/    -> ../.agents/rules     # 共通ルール（symlink）
  skills/   -> ../.agents/skills    # 共通スキル（symlink）

.gemini/                            # Gemini CLI
  settings.json                     # includeDirectoriesで.agents/rulesを直接参照
  skills/   -> ../.agents/skills    # 共通スキル（symlink）

.codex/                             # Codex CLI
                                    # config.toml配置用

AGENTS.md   -> .agents/rules/AGENTS.md  # Codexが読む共通ルール（symlink）
GEMINI.md                           # Gemini固有設定
```

## 共通ルールの読み込み経路

| エージェント | 経路 |
|---|---|
| Claude Code | `.claude/rules/` symlinkで `.agents/rules/` を参照 |
| Gemini CLI | `.gemini/settings.json` の `includeDirectories` で `.agents/rules/` を直接参照 |
| Codex CLI | ルートの `AGENTS.md` symlinkで `.agents/rules/AGENTS.md` を参照 |

## 共通スキルの読み込み経路

| エージェント | 経路 |
|---|---|
| Claude Code | `.claude/skills/` symlinkで `.agents/skills/` を参照 |
| Gemini CLI | `.gemini/skills/` symlinkで `.agents/skills/` を参照 |
| Codex CLI | `.agents/skills/` を直接参照（Codexの正規パス） |

## 固有設定

| エージェント | ファイル | 用途 |
|---|---|---|
| Claude Code | `.claude/CLAUDE.md` | Claude固有の指示・設定 |
| Gemini CLI | `GEMINI.md` | Gemini固有の指示・設定 |
| Codex CLI | `.codex/` | Codex固有の設定 |