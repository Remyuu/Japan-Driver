# Google Translation v2 直连翻译

## 工作方式

中文、英语和越南语翻译开关默认全部关闭，可以在练习设置中独立开启。开启任意语言后，客户端按以下顺序取译文：

1. 优先使用应用内人工中文译文。
2. 查询当前浏览器的本地翻译缓存。
3. 缓存不存在时，直接调用 Google Cloud Translation Basic v2：
   `https://translation.googleapis.com/language/translate/v2`。
4. 翻译成功后写入当前浏览器本地缓存；同一浏览器下次打开同题同语言会直接使用缓存。

本方案不使用 Firebase Functions，也不使用 Firestore。好处是部署简单；限制是缓存只保存在用户当前浏览器中，不会在所有用户之间共享。

## 费用与 API key

Cloud Translation Basic v2 支持 API key。Google 目前为 Cloud Translation 提供每月前 500,000 字符免费的额度，超出后按字符计费；仍建议在 Google Cloud Console 设置预算提醒和配额上限。

请不要把真实 API key 提交到 Git。项目通过 Dart define 读取：

```text
GOOGLE_TRANSLATE_API_KEY
```

本地部署配置文件 `.firebase-config.json` 已被 Git 忽略，可以在里面加入：

```json
{
  "GOOGLE_TRANSLATE_API_KEY": "your-google-translation-api-key"
}
```

如果同一个文件里还有 Firebase Auth 的配置，直接保留原字段并追加 `GOOGLE_TRANSLATE_API_KEY` 即可。

## Google Cloud Console 配置

在 Google Cloud Console 中：

1. 选择 API key 所属项目。
2. 启用 Cloud Translation API。
3. 打开 API key 限制：
   - Application restrictions：建议选择 HTTP referrers。
   - Website restrictions：加入正式域名，例如 `https://remoooo.com/*`。
   - API restrictions：限制为 Cloud Translation API。
4. 设置预算提醒或 Translation API 配额，避免异常流量产生费用。

## 本地测试

```bash
/Users/remosama/development/flutter/bin/flutter run -d chrome \
  --dart-define-from-file=.firebase-config.json
```

测试步骤：

1. 打开任意没有人工译文的题目。
2. 在右上角设置中分别开启 English 或 Tiếng Việt。
3. 首次打开应显示对应语言的加载提示，随后显示 Google 翻译结果。
4. 刷新页面或重新打开同一题，确认同一浏览器直接命中本地缓存。

## 部署

部署脚本 `scripts/deploy_remoooo.sh` 会自动读取 `.firebase-config.json`：

```bash
./scripts/deploy_remoooo.sh
```

如果只想临时传入 API key，也可以在构建时直接传入：

```bash
/Users/remosama/development/flutter/bin/flutter build web \
  --release \
  --base-href /jp-driver/ \
  --dart-define=GOOGLE_TRANSLATE_API_KEY=your-google-translation-api-key
```
