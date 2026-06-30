# Japan Driver 开发文档

## 技术概览

- Flutter Web
- Riverpod 状态管理
- GoRouter 页面路由
- SharedPreferences 本地进度存储
- Firebase Auth / Google 登录
- Nginx 静态部署

项目优先支持 Web，同时保留 Flutter 的移动端和桌面端复用能力。

## 本地环境

当前 Flutter SDK 路径：

```bash
/Users/remosama/development/flutter/bin/flutter
```

安装依赖并启动 Web 应用：

```bash
/Users/remosama/development/flutter/bin/flutter pub get
/Users/remosama/development/flutter/bin/flutter run -d chrome
```

## Firebase 配置

Google 登录所需配置保存在项目根目录的 `.firebase-config.json`。该文件已被 Git 忽略，本地模板为 `.firebase-config.example.json`。

新环境中先创建配置文件：

```bash
cp .firebase-config.example.json .firebase-config.json
```

然后填写对应 Firebase Web 项目的配置。Firebase Console 中还需要：

- 启用 Authentication 的 Google 登录提供方。
- 将 `remoooo.com` 加入 Authorized domains。

带 Firebase 配置构建：

```bash
/Users/remosama/development/flutter/bin/flutter build web \
  --base-href /jp-driver/ \
  --dart-define-from-file=.firebase-config.json
```

## 题库数据

本地题库位于 `scraped/`，包含题目、图片和相关资源。该目录不会提交到 Git，但 Flutter 构建时会将其打包进 `build/web`。

因此：

- 修改本地 `scraped/` 后重新部署，线上题库会一起更新。
- Git push 不会单独上传题库。
- 在另一台电脑开发时，需要另外准备 `scraped/` 目录。

题库内容目前用于私有验证。公开发布前需要确认题目、图片和音频的使用授权。

## 检查与构建

```bash
/Users/remosama/development/flutter/bin/flutter analyze
/Users/remosama/development/flutter/bin/flutter test
/Users/remosama/development/flutter/bin/flutter build web \
  --release \
  --base-href /jp-driver/ \
  --dart-define-from-file=.firebase-config.json
```

在本地预览已经构建的版本：

```bash
python3 -m http.server 8787 --directory build/web
```

## 部署

网站部署地址：<https://remoooo.com/jp-driver/>

代码或题库修改完成后，在项目根目录运行：

```bash
./scripts/deploy_remoooo.sh
```

部署脚本会自动：

1. 读取本地 `.firebase-config.json`。
2. 以 `/jp-driver/` 为基础路径构建 Flutter Web release。
3. 将 `build/web/` 同步到服务器。
4. 检查配置并重新加载 Nginx。

可通过环境变量覆盖部署参数：

```bash
FLUTTER_BIN=/path/to/flutter \
SSH_KEY=/path/to/key.pem \
REMOTE=root@example.com \
REMOTE_DIR=/path/on/server \
./scripts/deploy_remoooo.sh
```

当前默认值定义在 `scripts/deploy_remoooo.sh` 中。

## Git 与线上同步

Git 和线上部署是两个独立动作。提交并推送代码不会自动更新网站；部署脚本始终使用这台电脑上的当前文件，包括未纳入 Git 的本地题库。

推荐更新流程：

```bash
# 检查修改
/Users/remosama/development/flutter/bin/flutter analyze
/Users/remosama/development/flutter/bin/flutter test

# 提交源代码（按需）
git add .
git commit -m "update"
git push

# 发布当前本地版本
./scripts/deploy_remoooo.sh
```
