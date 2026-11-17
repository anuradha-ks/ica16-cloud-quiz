# ☁️ ICA 16 – Cloud Quiz

A Flutter-based cloud-enabled quiz application that fetches General Knowledge questions from the Open Trivia Database (OpenTDB), authenticates users with Firebase Authentication, and securely stores quiz attempts in Cloud Firestore.

## 📌 Project Overview

Cloud Quiz allows users to sign in, attempt a 10-question General Knowledge quiz, review their answers, and securely save their scores to Firebase.

The application demonstrates REST API integration, cloud authentication, transactional database operations, and server-side verification.

## ✨ Features

- **User Authentication:** Register and sign in using Firebase Authentication (Email/Password).
- **Dynamic Questions:** Fetches 10 easy General Knowledge questions from OpenTDB.
- **Question Validation:** Validates API responses, question categories, difficulty, and answer choices.
- **Interactive Quiz:** Presents multiple-choice questions with shuffled answer options.
- **Score Calculation:** Calculates the score and provides a review of submitted answers.
- **Cloud Storage:** Saves quiz attempts in Cloud Firestore.
- **Transactional Submission:** Uses Firestore transactions to prevent duplicate attempt records.
- **Server Verification:** Confirms saved attempts using a server-only read.
- **User Data Isolation:** Firestore security rules restrict access to each user's own attempts.

## 🛠️ Technologies Used

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application development |
| Dart | Application programming language |
| Firebase Authentication | User registration and login |
| Cloud Firestore | Cloud database for quiz attempts |
| Open Trivia Database | General Knowledge questions |
| HTTP | REST API communication |

## 🏗️ Application Workflow

1. User registers or signs in.
2. Application fetches questions from OpenTDB.
3. API response is validated and answer options are shuffled.
4. User answers 10 multiple-choice questions.
5. Application calculates the final score.
6. Quiz attempt is saved to Firestore using a transaction.
7. Application retrieves the saved record from the server.
8. The user sees the cloud verification result and reviews the quiz.

## 🌐 API Integration

Questions are retrieved from:

```text
https://opentdb.com/api.php?amount=10&category=9&difficulty=easy&type=multiple
```

- Amount: 10 questions
- Category: General Knowledge (ID 9)
- Difficulty: Easy
- Type: Multiple Choice

Source: [Open Trivia Database](https://opentdb.com/)

## 🔥 Firebase Configuration

The application uses:

- **Firebase Authentication:** Email and Password authentication.
- **Cloud Firestore:** Stores quiz attempts under individual authenticated users.

### Firestore Data Structure

```text
users/
  {uid}/
    attempts/
      {roundId}/
        schemaVersion
        variant
        categoryId
        questionCount
        correctCount
        submittedAt
```

Each attempt contains exactly six fields:

| Field | Type | Description |
|---|---|---|
| schemaVersion | Integer | Schema version (`1`) |
| variant | String | Quiz variant (`"A"`) |
| categoryId | Integer | OpenTDB category (`9`) |
| questionCount | Integer | Total questions (`10`) |
| correctCount | Integer | Number of correct answers |
| submittedAt | Timestamp | Firestore server timestamp |

Firestore security rules enforce user-level access, validate attempt creation, and prevent modification or deletion of submitted attempts.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Android Studio or Visual Studio Code
- Firebase project
- Git

### 1. Clone the repository

```bash
git clone https://github.com/anuradha-ks/ica16-cloud-quiz.git
cd ica16-cloud-quiz
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Configure Firebase for your own project using FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Enable Email/Password authentication and create a Cloud Firestore database in your Firebase project.

Deploy the project's Firestore security rules before testing cloud operations.

### 4. Run the application

```bash
flutter run
```

## 📦 Build Release APK

Generate an Android release APK using:

```bash
flutter build apk --release
```

APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 📸 Screenshots

Add application screenshots here to demonstrate:

- Login and registration
- Quiz interface
- Quiz completion and score review
- Cloud verification
- Firestore attempt document

## 👩‍💻 Author

**Sai Anuradha Kappaganthula**

GitHub: [@anuradha-ks](https://github.com/anuradha-ks)

## 📄 License

This project was developed as part of an academic assignment (ICA 16 – Cloud Quiz).
