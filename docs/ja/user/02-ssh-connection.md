# SSH 接続する

VSCode 派・ターミナル派共通の手順です。

---

## 1. SSH 鍵を生成する（初回のみ）

```bash
# Generate ED25519 key pair
ssh-keygen -t ed25519 -C "your-name@sinix.com"
# Save to default location: ~/.ssh/id_ed25519

# Display public key to register in Sakura Cloud
cat ~/.ssh/id_ed25519.pub
```

上記の出力（`ssh-ed25519 ...` で始まる1行）をさくらのクラウドのサーバー作成時に登録します。

---

## 2. SSH config を設定する

`~/.ssh/config` に以下を追記すると接続が楽になります。

```
Host sakura-vrt
    HostName <サーバーのIPアドレス>
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
```

接続：

```bash
ssh sakura-vrt
```

> IP アドレスはサーバーを作るたびに変わります。新しいサーバーを起動したら `HostName` を更新してください。

---

## 3. 接続確認

SSH 接続後、以下を確認します。

```bash
# Confirm GPU is visible
nvidia-smi

# Confirm Docker works with GPU
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi

# Confirm storage is mounted (if additional disk is attached)
df -h /mnt/data
```

`/mnt/data` が表示されれば追加ディスクの自動セットアップが成功しています。

---

## 4. GHCR にログイン（初回のみ）

Docker イメージを GHCR から pull するために認証が必要です。

1. GitHub で Personal Access Token（PAT）を発行
   - Settings → Developer settings → Personal access tokens → Tokens (classic)
   - スコープ：`read:packages` にチェック

2. ログイン

```bash
echo "<YOUR_PAT>" | docker login ghcr.io -u <YOUR_GITHUB_USERNAME> --password-stdin
```

> PAT は `.bashrc` に書かず、上記コマンドで都度ログインするか、`~/.docker/config.json` に保存されます（自動）。
