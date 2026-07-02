const {createHash} = require("node:crypto");

const QUESTION_ID_PATTERN = /^[A-Za-z0-9_-]{1,160}$/;
const MAX_QUESTION_LENGTH = 1200;
const MAX_EXPLANATION_LENGTH = 4000;

function computeSourceHash(question, explanation) {
  return createHash("sha256")
    .update(question, "utf8")
    .update("\0", "utf8")
    .update(explanation, "utf8")
    .digest("hex");
}

function parseTranslationRequest(data, sourceHashes) {
  if (data == null || typeof data !== "object" || Array.isArray(data)) {
    throw new TypeError("invalid-request");
  }

  const questionId = typeof data.questionId === "string"
    ? data.questionId.trim()
    : "";
  const question = typeof data.question === "string"
    ? data.question.trim()
    : "";
  const explanation = typeof data.explanation === "string"
    ? data.explanation.trim()
    : "";

  if (!QUESTION_ID_PATTERN.test(questionId)) {
    throw new TypeError("invalid-question-id");
  }
  if (question.length === 0 || question.length > MAX_QUESTION_LENGTH) {
    throw new TypeError("invalid-question");
  }
  if (explanation.length > MAX_EXPLANATION_LENGTH) {
    throw new TypeError("invalid-explanation");
  }

  const sourceHash = computeSourceHash(question, explanation);
  const allowedHashes = sourceHashes[questionId];
  if (!Array.isArray(allowedHashes) || !allowedHashes.includes(sourceHash)) {
    throw new TypeError("unknown-question-source");
  }

  return {
    questionId,
    question,
    explanation,
    sourceHash,
    generateIfMissing: data.generateIfMissing !== false,
  };
}

function readyTranslation(data, sourceHash) {
  if (
    data == null ||
    data.status !== "ready" ||
    data.sourceHash !== sourceHash ||
    typeof data.question !== "string" ||
    data.question.trim().length === 0
  ) {
    return null;
  }

  return {
    question: data.question,
    explanation:
      typeof data.explanation === "string" ? data.explanation : "",
  };
}

function translationsFromResponse(response, includeExplanation) {
  const translations = response?.translations;
  const expectedLength = includeExplanation ? 2 : 1;
  if (!Array.isArray(translations) || translations.length !== expectedLength) {
    throw new Error("invalid-translation-response");
  }

  const values = translations.map((item) => item?.translatedText?.trim() ?? "");
  if (values[0].length === 0 || (includeExplanation && values[1].length === 0)) {
    throw new Error("empty-translation-response");
  }

  return {
    question: values[0],
    explanation: includeExplanation ? values[1] : "",
  };
}

module.exports = {
  computeSourceHash,
  parseTranslationRequest,
  readyTranslation,
  translationsFromResponse,
};
