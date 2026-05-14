# Sakura VRT Research Template

さくらインターネット 高火力 VRT（H100 GPU）を使った研究環境のセットアップテンプレートです。

インターンや研究者が GPU クラウドを効率よく・安全に使うための手順書・スクリプト・Issue テンプレートをまとめています。

---

## このテンプレートでできること

- GPU 環境（CUDA + Docker）を焼き込んだマイアーカイブの作成
- インターンのオンボーディング・オフボーディング管理（GitHub Issue テンプレート）
- VSCode Dev Container または CLI（Claude Code, Codex 等）での開発
- GHCR（GitHub Container Registry）を使ったコンテナイメージ管理
- 東大 miyabi 等の HPC クラスターへの移植（Apptainer）

---

## ディレクトリ構成

```
.
├── .github/
│   └── ISSUE_TEMPLATE/
│       ├── onboarding.md       インターン受け入れ時に作成
│       └── offboarding.md      インターン終了時に作成（オンボーディング時に事前作成）
├── docs/
│   └── ja/                     日本語版ドキュメント
│       ├── admin/              管理者向け（1回だけやる作業）
│       │   ├── 01-project-setup.md
│       │   └── 02-base-image-setup.md
│       └── user/               インターン・研究者向け
│           ├── 00-overview.md
│           ├── 01-server-creation.md
│           ├── 02-ssh-connection.md
│           ├── 03-devcontainer-vscode.md
│           ├── 03-devcontainer-cli.md
│           ├── 04-research-workflow.md
│           ├── 05-miyabi.md
│           └── recipes.md
└── scripts/
    ├── setup_storage.sh        ストレージ自動セットアップ（dm-cache）
    ├── shutdown_storage.sh     シャットダウン時のクリーンアップ
    ├── setup-storage.service   systemd ユニット
    └── check_gpu.sh            GPU 動作確認
```

---

## クイックスタート

### 管理者（初回のみ）

1. [プロジェクト・ユーザー作成](docs/ja/admin/01-project-setup.md)
2. [マイアーカイブ作成](docs/ja/admin/02-base-image-setup.md)

### インターン（毎回）

1. [全体構成を理解する](docs/ja/user/00-overview.md) ← **最初に読む**
2. [サーバーを起動する](docs/ja/user/01-server-creation.md)
3. [SSH 接続する](docs/ja/user/02-ssh-connection.md)
4. 開発環境を起動する
   - [VSCode / Cursor](docs/ja/user/03-devcontainer-vscode.md)
   - [ターミナル（Claude Code, Codex 等）](docs/ja/user/03-devcontainer-cli.md)
5. [研究・実験を行う](docs/ja/user/04-research-workflow.md)
6. [レシピ集（自動停止・再開・miyabi 移行など）](docs/ja/user/recipes.md)
7. [miyabi で大規模実験（必要な場合）](docs/ja/user/05-miyabi.md)

---

## 技術スタック

| 項目 | 内容 |
|---|---|
| GPU | NVIDIA H100 SXM 80GB |
| OS | Ubuntu 24.04 LTS |
| コンテナ | Docker + nvidia-container-toolkit |
| イメージレジストリ | GHCR（GitHub Container Registry） |
| 環境定義 | Dockerfile + `.devcontainer/devcontainer.json` |
| パッケージ管理 | uv + pyproject.toml |
| HPC 移植 | Apptainer（miyabi） |

---

## 多言語対応

- [日本語](docs/ja/)
- English（準備中）
- 中文（准备中）
