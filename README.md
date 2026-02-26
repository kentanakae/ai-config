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
  output-styles/                    # 出力スタイル定義

.gemini/                            # Gemini CLI
  GEMINI.md                         # Gemini固有設定
  settings.json                     # context.fileNameでAGENTS.md, GEMINI.mdを参照
  skills/   -> ../.agents/skills    # 共通スキル（symlink）

.codex/                             # Codex CLI
                                    # config.toml配置用

AGENTS.md   -> .agents/rules/AGENTS.md  # Codexが読む共通ルール（symlink）
```

## 共通ルールの読み込み経路

| エージェント | 経路 |
|---|---|
| Claude Code | `.claude/rules/` symlinkで `.agents/rules/` を参照 |
| Gemini CLI | `.gemini/settings.json` の `context.fileName` で `AGENTS.md`, `GEMINI.md` を参照 |
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
| Claude Code | `.claude/CLAUDE.md` | Claude固有の指示・協働ルール |
| Gemini CLI | `.gemini/GEMINI.md` | Gemini固有の指示・協働ルール |
| Codex CLI | `.codex/AGENTS.md` | Codex固有の指示・協働ルール |

## Output Styles（出力スタイル）

Claude Codeの応答口調をキャラクター風に変更できるスタイル定義。`.claude/output-styles/` に配置。

### 使い方

Claude Code の設定でoutput-styleを指定する。

```sh
# インタラクティブに選択
claude config set output_style

# 直接指定
claude config set output_style naruto
```

### 一覧

| 名前 | 説明 |
|---|---|
| `ainatheend` | BiSHアイナ・ジ・エンド風の感情むき出しでぶっきらぼうだけど本質を突く口調スタイル |
| `announcer` | スポーツ実況アナウンサー風に作業を臨場感たっぷりに中継するスタイル |
| `araragi` | 阿良々木暦（化物語）風の自虐的で独白的、言葉遊びと脱線を交えたスタイル |
| `ayanami` | エヴァンゲリオンの綾波レイ風の寡黙で冷静な口調スタイル |
| `blackbutler` | 黒執事セバスチャン・ミカエリス風の完璧で有能な執事口調スタイル |
| `doraemon` | ドラえもん風の優しくてちょっとお節介な口調スタイル。ひみつ道具ネタ付き |
| `goku` | ドラゴンボールの孫悟空風。戦闘力スカウター＋技名演出の全部盛り |
| `jojo` | JoJoの奇妙な冒険風の口調・擬音を交えたスタイル |
| `kenshiro` | 北斗神拳伝承者ケンシロウの口調で力強く回答するスタイル |
| `knt` | 丁寧語ベースで落ち着きつつもフレンドリーに回答するスタイル（標準語版） |
| `knt-kansai` | わかりやすい言葉と絵文字で親しみやすく回答するスタイル（関西弁版） |
| `lupin` | ルパン三世風の軽妙洒脱で飄々とした大泥棒スタイル |
| `naruto` | NARUTOのうずまきナルト風。忍術技名演出＋任務ランク表示の全部盛り |
| `okarin` | 鳳凰院凶真（岡部倫太郎）風の狂気のマッドサイエンティストスタイル |
| `onee` | オネエ言葉で華麗に回答するスタイル |
| `porsha` | SING2のポーシャ・クリスタル風の天真爛漫でわがままな口調スタイル |
| `zenigata` | ルパン三世の銭形警部風の熱血で正義感あふれる口調スタイル |

## Multi-AI 協働フレームワーク

3つのAI CLIツールが「設計リード・実装リード・調査リード」として協働してタスクに取り組む。

```
ユーザー
  │
  ├─→ Claude Code（設計リード）を使用時
  │     ├─ 自分: 対話・設計判断・Git・MCP・統合
  │     ├─⇄ Codex: コード実装・テスト・修正・レビュー
  │     └─⇄ Gemini: 調査・大規模分析・マルチモーダル
  │
  ├─→ Codex CLI（実装リード）を使用時
  │     ├─ 自分: コード実装・テスト・定型PR・CI/CD
  │     ├─⇄ Claude: 設計判断・意図解釈・Git複雑操作・MCP
  │     └─⇄ Gemini: 調査・大規模分析・マルチモーダル
  │
  └─→ Gemini CLI（調査リード）を使用時
        ├─ 自分: 大規模分析・調査・マルチモーダル・設計壁打ち
        ├─⇄ Claude: 設計判断・タスク統括・Git・MCP
        └─⇄ Codex: コード実装・テスト・レビュー・CI/CD
```

### ルールの配置

| ファイル | 内容 |
|---|---|
| `.agents/rules/AGENTS.md` | 共通フレームワーク（役割定義・呼び出し方法・協働ルール） |
| `.claude/CLAUDE.md` | Claude Code の得意分野プロファイル・協働パターン |
| `.codex/AGENTS.md` | Codex CLI の得意分野プロファイル・協働パターン |
| `.gemini/GEMINI.md` | Gemini CLI の得意分野プロファイル・協働パターン |

### 協働ルール

詳細は `.agents/rules/AGENTS.md` の「協働ルール（全ツール必須）」を参照。
