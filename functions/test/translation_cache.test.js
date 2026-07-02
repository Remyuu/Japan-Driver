const test = require("node:test");
const assert = require("node:assert/strict");

const {
  computeSourceHash,
  parseTranslationRequest,
  readyTranslation,
  translationsFromResponse,
} = require("../src/translation_cache");

test("accepts only a known question source", () => {
  const question = "黄色の点滅信号では注意して進行できる。";
  const explanation = "他の交通に注意します。";
  const hash = computeSourceHash(question, explanation);

  const parsed = parseTranslationRequest(
    {questionId: "5536", question, explanation},
    {5536: [hash]},
  );

  assert.equal(parsed.sourceHash, hash);
  assert.equal(parsed.generateIfMissing, true);
  assert.throws(
    () => parseTranslationRequest(
      {questionId: "5536", question: `${question}改`, explanation},
      {5536: [hash]},
    ),
    /unknown-question-source/,
  );
});

test("returns only a ready translation for the current source", () => {
  assert.deepEqual(
    readyTranslation(
      {
        status: "ready",
        sourceHash: "current",
        question: "中文题目",
        explanation: "中文解析",
      },
      "current",
    ),
    {question: "中文题目", explanation: "中文解析"},
  );
  assert.equal(
    readyTranslation(
      {status: "ready", sourceHash: "old", question: "旧译文"},
      "current",
    ),
    null,
  );
});

test("maps Google translations in request order", () => {
  assert.deepEqual(
    translationsFromResponse(
      {
        translations: [
          {translatedText: " 中文题目 "},
          {translatedText: "中文解析"},
        ],
      },
      true,
    ),
    {question: "中文题目", explanation: "中文解析"},
  );
});
