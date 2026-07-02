# Japan Driver

An online tool for the Japanese driver’s license written exam, covering the two learning stages before the provisional license test and before the final graduation test.

[Use Online](https://remoooo.com/jp-driver/) · [Development Docs](docs/development.md)

## Product Overview

Japan Driver organizes Japanese driver’s license written exam questions into a Web app suited for daily practice. You can choose questions by exam stage, practice mode, or textbook chapter, review explanations after answering, and continuously track your completion progress and weak areas.

## Main Features

* **Stage-based preparation**: Provides separate question sets for the pre-provisional-license stage and the pre-graduation-test stage.
* **Multiple practice modes**: Supports one-question-at-a-time practice, exam-style practice, category-based practice, and frequently missed questions.
* **Japanese reading support**: Questions and explanations support furigana, images, and textbook references.
* **Multilingual translation comparison**: Chinese, English, and Vietnamese can be enabled independently; untranslated content is translated live with Google and cached per language on the server.
* **Learning progress statistics**: View answered question count, accuracy rate, number of mistakes, and completion progress for each question bank.
* **Mistake review and answer history**: Saves practice results so you can review answers and explanations later.
* **Question notes**: Add your own notes to individual questions.
* **Google account**: Supports registration and login with a Google account.
* **Multi-device layout**: Usable in desktop and mobile browsers.

## Getting Started

Open [Japan Driver](https://remoooo.com/jp-driver/), then choose your current study stage and practice mode to start answering questions.

At the moment, learning progress, answer history, and question notes are stored in the current browser. These records will not sync automatically if you clear site data or switch devices.

## Project Status

The product is still under active development. The current version prioritizes the Web experience for question practice, records, and statistics.

All translation switches default to off. The small set of curated Chinese translations lives in `assets/translations_zh.json`; optional `question_zh` and `explanation_zh` fields inside question-bank JSON are also supported. All other translations are generated through Google Cloud Translation and cached in Firestore by question and target language. See the [translation backend guide](docs/translation_backend.md) for setup and testing.

The question bank, images, and audio content are currently used only for product validation. Relevant content licenses should be confirmed before public release.
