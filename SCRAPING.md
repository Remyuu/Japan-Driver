# MUSASI 日语「一问一答・仮免前」抓取

抓取器以网站当前显示的菜单为准，先读取：

`/workbook/4/9086/no`

再进入每套卷。每题先 GET `/question/{n}` 读取题目，然后不选择 ○/×，直接 POST“正解と解説”，从 `/question/explanation/{n}` 读取正确答案与解析。

账号密码不会写入源码或结果文件。运行方式：

```bash
MUSASI_USERNAME='你的账号' MUSASI_PASSWORD='你的密码' \
python3 scripts/scrape_musasi_ja_karimen.py --download-images --force
```

输出目录为 `scraped/musasi_ja_karimen/`：

- `workbook_01_id_29.json` 等：每套卷的独立数据与进度检查点
- `karimen_1to1_all.json`：六套合并数据
- `manifest.json`：卷 ID、题目数量和去重统计
- `images/`：只包含题目图和解析图，不包含网站按钮图

部分标志题没有“虎の巻 / 動画 / 類似問題”链接，页面因此不公开内部题目 ID；这类记录的 `question_id` 为 `null`，可用 `question_key` 和 `asset_codes` 稳定追踪，不会猜造 ID。

## 日语「一问一答・卒検前」

卒検前入口为 `/workbook/4/9087/no`。抓取流程和仮免前一问一答相同：当前菜单列出 35～40 六套，每套 95 题。

```bash
MUSASI_USERNAME='你的账号' MUSASI_PASSWORD='你的密码' \
python3 scripts/scrape_musasi_ja_karimen.py \
  --workbook-list-path /workbook/4/9087/no \
  --stage '卒検前' \
  --category-id 9087 \
  --output-dir scraped/musasi_ja_sotsuken \
  --aggregate-name sotsuken_1to1_all.json \
  --workbook-ids 35 36 37 38 39 40 \
  --download-images
```

输出位于 `scraped/musasi_ja_sotsuken/`。

## 日语「测试形式・仮免前」

测试形式必须先交卷才能打开解析页。抓取器会给 1～50 题全部提交 `○`，正常交卷后根据结果页的“正解 / 不正解”反推答案，再访问每题已解锁的解析页进行二次核对：

```bash
MUSASI_USERNAME='你的账号' MUSASI_PASSWORD='你的密码' \
python3 scripts/scrape_musasi_ja_test_karimen.py --download-images --force
```

输出位于 `scraped/musasi_ja_test_karimen/`。每套运行都会在 MUSASI 账号中产生一条真实的测试成绩记录。

## 日语「教習項目別問題・第一段階」

章节模式每次最多生成 50 题；题池较小的章节会提前结束（实测第 14 章为 32 题）。同一章节重复运行可能抽到新题。抓取器按 1～14 章分别运行，默认每章至少 3 轮、最多 6 轮，连续两轮没有新增题时提前停止。答题前会先与已经抓取的日语题库匹配正确答案：无图/无音频题按题干匹配，有图/音频题按“题干 + 资源码组合”匹配；匹配不到时提交 `○`，随后用解析页校验。图片/音频素材编号会被保存，但默认不单独用素材编号推断答案，因为同一素材或同一题干可能出现在不同真伪题里；如需诊断旧策略，可显式加 `--allow-asset-answer-match`。

```bash
MUSASI_USERNAME='你的账号' MUSASI_PASSWORD='你的密码' \
python3 scripts/scrape_musasi_ja_curriculum_stage1.py --download-images
```

默认在答题前随机等待 0.25～0.75 秒，在进入下一题前随机等待 0.10～0.35 秒。这是降低请求突发的礼貌节流，不保证规避站点风控。

可用 `--chapters 1 2 3` 只跑指定章节；重新抓已完成章节时需要显式添加 `--force`。

第二阶段使用同一个抓取器，但菜单容器和输出目录不同。当前网站实际显示的第二阶段章节为 `1, 4–18`，没有 2、3。

```bash
MUSASI_USERNAME='你的账号' MUSASI_PASSWORD='你的密码' \
python3 scripts/scrape_musasi_ja_curriculum_stage1.py \
  --stage-index 2 \
  --stage-label '第二段階' \
  --expected-chapter-count 16 \
  --output-dir scraped/musasi_ja_curriculum_stage2 \
  --aggregate-name curriculum_stage2_all.json \
  --download-images
```

## 日语「みんな苦手問題」

入口为 `/difficult`。菜单实际显示：

- `step=1`：第一段階 100問
- `step=2`：第二段階 100問
- `step=3`：全てから 300問

当前抓取器只默认抓第一阶段和第二阶段。每题题目页会记录 `school_accuracy_rate`（页面标签为 `教習所内`，即当前安芸自动车学校范围）和 `nationwide_accuracy_rate`（页面标签为 `全国`）。有图/音频题同样按“题干 + 资源码组合”匹配历史答案，避免危险预测图题误匹配。

```bash
MUSASI_USERNAME='你的账号' MUSASI_PASSWORD='你的密码' \
python3 scripts/scrape_musasi_ja_difficult.py \
  --steps 1 2 \
  --output-dir scraped/musasi_ja_difficult \
  --aggregate-name difficult_all.json \
  --download-images
```

如果要多次抽取随机样本，可加 `--runs N`；每次会生成独立 session 文件，再合并去重。
