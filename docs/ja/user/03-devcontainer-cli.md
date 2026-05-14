# 開発環境を起動する（ターミナル派：Claude Code, Codex 等）

VSCode を使わず、ターミナルや Claude Code / Codex CLI で開発する場合の手順です。

---

## 1. SSH 接続

```bash
ssh sakura-vrt
```

SSH 接続時に追加ディスクの自動セットアップ（dm-cache）が実行されます。

---

## 2. プロジェクトを clone

```bash
git clone https://github.com/<your-org>/<your-project>.git
cd <your-project>
```

---

## 3. Docker コンテナを起動

```bash
docker run --gpus all \
  --shm-size 16g \
  -v /mnt/data:/workspace/data \
  -v /mnt/nvme:/workspace/.cache \
  -v $(pwd):/workspace/src \
  -w /workspace/src \
  -it --rm \
  ghcr.io/<your-org>/<your-project>:v1.0 \
  bash
```

---

## 4. GPU 確認

コンテナ内で：

```bash
nvidia-smi
python -c "import torch; print(torch.cuda.is_available())"
# True
```

---

## よく使うコマンド

### バックグラウンドで実験を実行

```bash
# Run training in background, keep alive after SSH disconnect
docker run --gpus all \
  --shm-size 16g \
  -v /mnt/data:/workspace/data \
  -v /mnt/nvme:/workspace/.cache \
  -v $(pwd):/workspace/src \
  -w /workspace/src \
  -d \
  --name training \
  ghcr.io/<your-org>/<your-project>:v1.0 \
  python train.py

# Check logs
docker logs -f training
```

### コンテナに途中参加

```bash
docker exec -it training bash
```

---

## Claude Code を使う場合

SSH 接続後、コンテナの外（ホスト上）で起動します。

```bash
ssh sakura-vrt
claude
```

コンテナ内でファイルを編集したい場合は `docker exec` で入るか、マウントしたディレクトリ（`/mnt/data`）を直接編集してください。

---

## ディレクトリ構成（コンテナ内）

```
/workspace/
├── data/   → 追加ディスク（永続・チェックポイント・実験結果）
├── .cache/ → NVMe（高速・HuggingFace キャッシュ等）
└── src/    → あなたのコード
```

重要なデータは必ず `/workspace/data/` 以下に保存してください。
