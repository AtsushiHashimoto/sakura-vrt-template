# 開発環境を起動する（VSCode / Cursor 派）

---

## 必要な拡張機能

VSCode または Cursor に以下をインストールします。

- **Remote - SSH** (`ms-vscode-remote.remote-ssh`)
- **Dev Containers** (`ms-vscode-remote.remote-containers`)

---

## 1. SSH 接続

1. コマンドパレット（`Cmd+Shift+P`）→「Remote-SSH: Connect to Host」
2. `sakura-vrt`（`~/.ssh/config` で設定した名前）を選択
3. リモートの VSCode Server が自動インストールされて接続完了

---

## 2. プロジェクトを clone

VSCode のターミナルで：

```bash
git clone https://github.com/<your-org>/<your-project>.git
cd <your-project>
```

---

## 3. .devcontainer を用意する

プロジェクトのルートに `.devcontainer/devcontainer.json` を作成します。

```json
{
  "image": "ghcr.io/<your-org>/<your-project>:v1.0",
  "runArgs": [
    "--gpus", "all",
    "--shm-size", "16g"
  ],
  "mounts": [
    "source=/mnt/data,target=/workspace/data,type=bind",
    "source=/mnt/nvme,target=/workspace/.cache,type=bind"
  ],
  "initializeCommand": "bash scripts/setup_storage.sh",
  "remoteUser": "ubuntu",
  "features": {}
}
```

> `initializeCommand` はコンテナ起動前にホスト上で実行されます。追加ディスクがアタッチされている場合に dm-cache を自動セットアップします。

---

## 4. Dev Container を起動

1. コマンドパレット →「Dev Containers: Reopen in Container」
2. GHCR から自動で image が pull され、コンテナが起動します
3. VSCode がコンテナ内に接続された状態になります

---

## 5. GPU 確認

コンテナ内のターミナルで：

```bash
nvidia-smi
python -c "import torch; print(torch.cuda.is_available())"
# True
```

---

## ディレクトリ構成（コンテナ内）

```
/workspace/
├── data/        → 追加ディスク（永続・チェックポイント・実験結果）
├── .cache/      → NVMe（高速・HuggingFace キャッシュ等）
└── src/         → あなたのコード（git clone した内容）
```

重要なデータは必ず `/workspace/data/` 以下に保存してください。
