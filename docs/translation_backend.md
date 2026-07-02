# 多语言翻译后端

## 工作方式

中文、英语和越南语翻译开关默认全部关闭，可以在练习设置中独立开启。开启任意语言后，客户端按以下顺序取译文：

1. 优先使用应用内人工译文。
2. 调用 `getQuestionTranslation` Firebase Callable Function。
3. 函数按题目 ID、目标语言和原文哈希查询 Firestore 的 `questionTranslations` 集合。
4. 缓存不存在时，函数调用 Google Cloud Translation v3，从日文 `ja` 翻译为简体中文 `zh-CN`、英语 `en` 或越南语 `vi`。
5. 译文按语言分别写入 Firestore；下一次访问相同语言时直接返回缓存，不再调用 Google 翻译。

函数只接受 `functions/question_source_hashes.json` 中登记的题目原文哈希，以及 `zh-CN`、`en`、`vi` 三个目标语言，不能被用作任意文本翻译接口。同一道题、同一种语言首次并发访问时使用 Firestore 租约避免重复调用 Google。

## 一次性云端配置

Cloud Functions 部署要求 Firebase 项目使用 Blaze 方案。先在 Firebase Console 创建 Firestore 数据库（Native mode），然后在同一个 Google Cloud 项目中启用 Cloud Translation API 和计费。

使用 `gcloud` 时可执行：

```bash
PROJECT_ID="your-firebase-project-id"

gcloud services enable \
  translate.googleapis.com \
  firestore.googleapis.com \
  cloudfunctions.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  --project "$PROJECT_ID"

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" \
  --format='value(projectNumber)')"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/cloudtranslate.user"
```

建议同时在 Google Cloud Console 设置预算提醒与 Translation API 配额上限。

## 更新题库哈希

题库内容发生变化后必须重新生成后端允许清单：

```bash
python3 scripts/generate_translation_source_hashes.py
```

脚本读取六个本地 `scraped/*/*_all.json` 题库，只提交题目 ID 和 SHA-256 哈希，不会把题目原文写入 Git。

## 本地自动测试

Flutter 端：

```bash
/Users/remosama/development/flutter/bin/flutter analyze
/Users/remosama/development/flutter/bin/flutter test
```

Functions 端：

```bash
cd functions
pnpm install --frozen-lockfile
pnpm run check
pnpm test
```

## 本地联调

Firebase Emulator 需要本机具有 Google Cloud Application Default Credentials，才能真正调用 Translation API：

```bash
gcloud auth application-default login
firebase emulators:start --only functions,firestore
```

另一个终端启动 Flutter：

```bash
/Users/remosama/development/flutter/bin/flutter run -d chrome \
  --dart-define-from-file=.firebase-config.json \
  --dart-define=FIREBASE_FUNCTIONS_EMULATOR_HOST=127.0.0.1 \
  --dart-define=FIREBASE_FUNCTIONS_EMULATOR_PORT=5001
```

测试步骤：

1. 打开任意没有人工译文的题目。
2. 在右上角设置中开启“显示中文对照”。
3. 分别开启中文、English、Tiếng Việt，确认三个翻译卡片按所选语言显示；全部关闭时不应显示翻译卡片。
4. 确认先显示“Google 翻译生成中…”，随后显示相应语言的题目。
5. 答题后确认解析区域也出现已开启语言的翻译。
6. 在 Emulator UI 查看 `questionTranslations/{题目ID}__{语言缓存键}`，或刷新页面确认第二次直接命中缓存。

## 部署后端

完成一次性配置后执行：

```bash
./scripts/deploy_translation_backend.sh
```

脚本会重新生成题库哈希、安装依赖、运行后端检查与测试，然后部署 Callable Function 和 Firestore Rules。静态 Flutter 网站仍由 `scripts/deploy_remoooo.sh` 单独发布。
