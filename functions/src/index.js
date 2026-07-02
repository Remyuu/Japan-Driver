const {setGlobalOptions} = require("firebase-functions/v2");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const {initializeApp} = require("firebase-admin/app");
const {
  FieldValue,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");
const {v3} = require("@google-cloud/translate");

const sourceHashes = require("../question_source_hashes.json");
const {
  parseTranslationRequest,
  readyTranslation,
  translationsFromResponse,
} = require("./translation_cache");

const app = initializeApp();
const db = getFirestore();
const translationClient = new v3.TranslationServiceClient();

const REGION = "asia-northeast1";
const LEASE_MILLISECONDS = 60_000;
const POLL_ATTEMPTS = 10;
const POLL_INTERVAL_MILLISECONDS = 500;

setGlobalOptions({
  region: REGION,
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: "256MiB",
});

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function acquireTranslationLease(documentReference, request) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(documentReference);
    const data = snapshot.data();
    const cached = readyTranslation(data, request.sourceHash);
    if (cached != null) {
      return {cached};
    }

    const leaseUntil = data?.leaseUntil?.toMillis?.() ?? 0;
    const hasActiveLease =
      data?.status === "translating" &&
      data?.sourceHash === request.sourceHash &&
      leaseUntil > Date.now();
    if (hasActiveLease) {
      return {waiting: true};
    }

    transaction.set(
      documentReference,
      {
        status: "translating",
        sourceHash: request.sourceHash,
        sourceLanguage: "ja",
        targetLanguage: "zh-CN",
        leaseUntil: Timestamp.fromMillis(Date.now() + LEASE_MILLISECONDS),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return {acquired: true};
  });
}

async function waitForTranslation(documentReference, sourceHash) {
  for (let attempt = 0; attempt < POLL_ATTEMPTS; attempt += 1) {
    await sleep(POLL_INTERVAL_MILLISECONDS);
    const snapshot = await documentReference.get();
    const cached = readyTranslation(snapshot.data(), sourceHash);
    if (cached != null) {
      return cached;
    }
  }
  return null;
}

async function translateWithGoogle(request) {
  const projectId =
    app.options.projectId || process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
  if (projectId == null || projectId.length === 0) {
    throw new Error("missing-google-cloud-project-id");
  }

  const contents = request.explanation.length === 0
    ? [request.question]
    : [request.question, request.explanation];
  const [response] = await translationClient.translateText({
    parent: `projects/${projectId}/locations/global`,
    contents,
    mimeType: "text/plain",
    sourceLanguageCode: "ja",
    targetLanguageCode: "zh-CN",
    labels: {app: "japan_driver"},
  });
  return translationsFromResponse(response, request.explanation.length > 0);
}

exports.getQuestionTranslation = onCall(async (callRequest) => {
  let request;
  try {
    request = parseTranslationRequest(callRequest.data, sourceHashes);
  } catch (error) {
    throw new HttpsError(
      "invalid-argument",
      "The question does not match the published question bank.",
    );
  }

  const documentReference = db
    .collection("questionTranslations")
    .doc(request.questionId);
  const initialSnapshot = await documentReference.get();
  const initialCached = readyTranslation(
    initialSnapshot.data(),
    request.sourceHash,
  );
  if (initialCached != null) {
    return {translation: initialCached, cached: true};
  }
  if (!request.generateIfMissing) {
    return {translation: null, cached: false};
  }

  const lease = await acquireTranslationLease(documentReference, request);
  if (lease.cached != null) {
    return {translation: lease.cached, cached: true};
  }
  if (lease.waiting === true) {
    const cached = await waitForTranslation(
      documentReference,
      request.sourceHash,
    );
    if (cached != null) {
      return {translation: cached, cached: true};
    }
    throw new HttpsError(
      "unavailable",
      "Translation is still being generated. Please retry.",
    );
  }

  try {
    const translation = await translateWithGoogle(request);
    await documentReference.set(
      {
        ...translation,
        status: "ready",
        sourceHash: request.sourceHash,
        sourceLanguage: "ja",
        targetLanguage: "zh-CN",
        provider: "google-cloud-translation-v3",
        leaseUntil: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return {translation, cached: false};
  } catch (error) {
    logger.error("Google translation failed", {
      questionId: request.questionId,
      error,
    });
    await documentReference.set(
      {
        status: "error",
        sourceHash: request.sourceHash,
        leaseUntil: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    throw new HttpsError(
      "internal",
      "The translation service is temporarily unavailable.",
    );
  }
});
