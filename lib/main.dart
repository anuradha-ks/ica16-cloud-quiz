import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

final auth = FirebaseAuth.instance;
final db = FirebaseFirestore.instance;
final unescape = HtmlUnescape();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ICA 16 Cloud Quiz',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
      ),
      home: const AuthPage(),
    );
  }
}

// ---------------- AUTHENTICATION ----------------

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool register = false;
  bool loading = false;
  String error = '';

  Future<void> authenticate() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      UserCredential result;

      if (register) {
        result = await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        result = await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }

      if (!mounted) return;

      if (result.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const QuizPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? e.code);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_circle,
                  size: 85,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 15),
                const Text(
                  'ICA 16 Cloud Quiz',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(register ? 'Create your account' : 'Welcome back'),
                const SizedBox(height: 30),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 15),
                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : authenticate,
                    child: Text(
                      loading
                          ? 'Please wait...'
                          : register
                          ? 'Register'
                          : 'Sign In',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      register = !register;
                      error = '';
                    });
                  },
                  child: Text(
                    register
                        ? 'Already have an account? Sign in'
                        : 'New user? Create an account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- QUESTION MODEL ----------------

class Question {
  final String question;
  final String correct;
  final List<String> options;

  Question({
    required this.question,
    required this.correct,
    required this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final q = unescape.convert(json['question'].toString());
    final correct = unescape.convert(json['correct_answer'].toString());

    final wrong = (json['incorrect_answers'] as List)
        .map((e) => unescape.convert(e.toString()))
        .toList();

    if (q.trim().isEmpty || correct.trim().isEmpty || wrong.length != 3) {
      throw Exception('Invalid question data');
    }

    final options = [correct, ...wrong];

    if (options.any((e) => e.trim().isEmpty) || options.toSet().length != 4) {
      throw Exception('Invalid or duplicate answer choices');
    }

    options.shuffle(Random());

    return Question(question: q, correct: correct, options: options);
  }
}

// ---------------- QUIZ SCREEN ----------------

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Question> questions = [];
  final Map<int, String> answers = {};

  int current = 0;
  bool loading = true;
  bool submitting = false;
  bool completed = false;
  String error = '';
  String status = '';

  DocumentReference<Map<String, dynamic>>? roundRef;

  int get score {
    int total = 0;
    for (int i = 0; i < questions.length; i++) {
      if (answers[i] == questions[i].correct) total++;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    startRound();
  }

  Future<void> startRound() async {
    setState(() {
      loading = true;
      error = '';
      status = '';
      completed = false;
      submitting = false;
      current = 0;
      questions = [];
      answers.clear();
    });

    roundRef = db
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('attempts')
        .doc();

    try {
      final uri = Uri.https('opentdb.com', '/api.php', {
        'amount': '10',
        'category': '9',
        'difficulty': 'easy',
        'type': 'multiple',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (data['response_code'] != 0) {
        throw Exception('Trivia API error: ${data['response_code']}');
      }

      final results = data['results'];

      if (results is! List || results.length != 10) {
        throw Exception('Expected exactly 10 questions');
      }

      final parsed = results.map<Question>((item) {
        if (item['category'] != 'General Knowledge' ||
            item['difficulty'] != 'easy' ||
            item['type'] != 'multiple') {
          throw Exception('Question does not match Class A requirements');
        }
        return Question.fromJson(item);
      }).toList();

      if (!mounted) return;

      setState(() {
        questions = parsed;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  void chooseAnswer(String answer) {
    if (answers.containsKey(current) || completed) return;

    setState(() => answers[current] = answer);
  }

  void nextQuestion() {
    if (!answers.containsKey(current)) return;

    if (current < questions.length - 1) {
      setState(() => current++);
    } else {
      setState(() => completed = true);
    }
  }

  // ---------------- FIRESTORE TRANSACTION ----------------

  Future<void> submitScore() async {
    if (submitting || status == 'Cloud verified') return;
    if (answers.length != 10 || roundRef == null) return;

    setState(() {
      submitting = true;
      status = 'Saving attempt...';
    });

    final ref = roundRef!;

    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'variant': 'A',
      'categoryId': 9,
      'questionCount': 10,
      'correctCount': score,
      'submittedAt': FieldValue.serverTimestamp(),
    };

    try {
      await db.runTransaction((transaction) async {
        final existing = await transaction.get(ref);

        if (!existing.exists) {
          transaction.set(ref, payload);
        } else {
          final old = existing.data()!;

          const fields = [
            'schemaVersion',
            'variant',
            'categoryId',
            'questionCount',
            'correctCount',
          ];

          final matches = fields.every((field) => old[field] == payload[field]);

          if (!matches) {
            throw Exception('Round ID collision: payload mismatch');
          }
        }
      });

      if (!mounted) return;

      setState(() => status = 'Verifying from server...');

      final verified = await ref.get(const GetOptions(source: Source.server));

      final data = verified.data();

      const fields = [
        'schemaVersion',
        'variant',
        'categoryId',
        'questionCount',
        'correctCount',
      ];

      final matches =
          verified.exists &&
          data != null &&
          fields.every((field) => data[field] == payload[field]) &&
          data.length == 6 &&
          data['submittedAt'] is Timestamp &&
          !verified.metadata.hasPendingWrites;

      if (!matches) {
        throw Exception('Server verification did not match');
      }

      if (!mounted) return;

      setState(() => status = 'Cloud verified');
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        status = e.code == 'permission-denied'
            ? 'Permission denied: check Firestore rules'
            : e.code == 'unauthenticated'
            ? 'Authentication required'
            : e.code == 'resource-exhausted'
            ? 'Quota exhausted'
            : 'Verification unavailable: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => status = 'Verification unavailable: $e');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('General Knowledge Quiz'),
        actions: [
          IconButton(
            onPressed: submitting
                ? null
                : () async {
                    await auth.signOut();
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthPage()),
                    );
                  },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: 15),
                    FilledButton(
                      onPressed: startRound,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : completed
          ? reviewScreen()
          : quizScreen(),
    );
  }

  Widget quizScreen() {
    final q = questions[current];
    final selected = answers[current];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Question ${current + 1} of 10',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: (current + 1) / 10),
              const SizedBox(height: 30),
              Text(
                q.question,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              ...q.options.map((option) {
                final isSelected = selected == option;
                final isCorrect = option == q.correct;

                Color? color;
                if (selected != null) {
                  if (isCorrect) {
                    color = Colors.green.shade100;
                  } else if (isSelected) {
                    color = Colors.red.shade100;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: color,
                    child: ListTile(
                      title: Text(option),
                      trailing: selected == null
                          ? null
                          : isCorrect
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : isSelected
                          ? const Icon(Icons.cancel, color: Colors.red)
                          : null,
                      onTap: selected == null
                          ? () => chooseAnswer(option)
                          : null,
                    ),
                  ),
                );
              }),
              const Spacer(),
              if (selected != null)
                Text(
                  selected == q.correct
                      ? 'Correct answer!'
                      : 'Incorrect. Correct answer: ${q.correct}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected == q.correct ? Colors.green : Colors.red,
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: selected == null ? null : nextQuestion,
                child: Text(current == 9 ? 'Finish Quiz' : 'Next Question'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget reviewScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.emoji_events, size: 65, color: Colors.deepPurple),
            Center(
              child: Text(
                'Your Score: $score / 10',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Answer Review',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...List.generate(questions.length, (i) {
              final q = questions[i];
              final selected = answers[i];
              final correct = selected == q.correct;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}. ${q.question}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Your answer: $selected'),
                      Text('Correct answer: ${q.correct}'),
                      Text(
                        correct ? 'Correct' : 'Incorrect',
                        style: TextStyle(
                          color: correct ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: submitting ? null : submitScore,
              icon: const Icon(Icons.cloud_upload),
              label: Text(submitting ? 'Please wait...' : 'Submit Score'),
            ),
            const SizedBox(height: 12),
            SelectableText(status),
            if (status == 'Cloud verified' && roundRef != null)
              SelectableText('Verified path: ${roundRef!.path}'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: submitting ? null : startRound,
              child: const Text('Replay Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}
