import 'dart:convert';
import 'dart:io';

// ============================================================
// EXCEPTIONS PERSONNALISÉES
// ============================================================

abstract class TaskException implements Exception {
  final String message;
  TaskException(this.message);

  @override
  String toString() => message;
}

class TaskNotFoundException extends TaskException {
  TaskNotFoundException(String id) : super('Tâche introuvable avec id: $id');
}

class EmptyTitleException extends TaskException {
  EmptyTitleException() : super('Le titre de la tâche ne peut pas être vide.');
}

class InvalidPriorityException extends TaskException {
  InvalidPriorityException(String value)
      : super('Priorité invalide: "$value" (attendu: low, medium ou high).');
}

class InvalidDateException extends TaskException {
  InvalidDateException(String value)
      : super('Date invalide: "$value" (format attendu: jj/mm/aaaa).');
}

// ============================================================
// MODÈLES : enum, interface, classe abstraite, héritage
// ============================================================

enum Priority { low, medium, high }

Priority priorityFromString(String value) {
  switch (value.trim().toLowerCase()) {
    case 'low':
      return Priority.low;
    case 'medium':
      return Priority.medium;
    case 'high':
      return Priority.high;
    default:
      throw InvalidPriorityException(value);
  }
}

DateTime parseDate(String value) {
  try {
    final parts = value.split('/');
    if (parts.length != 3) throw const FormatException();
    return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
  } catch (_) {
    throw InvalidDateException(value);
  }
}

abstract class Completable {
  void markCompleted();
}

abstract class Task {
  final String id;
  String title;
  Priority priority;
  DateTime? dueDate;
  bool completed;

  Task({
    required this.id,
    required this.title,
    required this.priority,
    this.dueDate,
    this.completed = false,
  });

  String get type;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority.name,
        'dueDate': dueDate?.toIso8601String(),
        'completed': completed,
        'type': type,
      };

  static Task fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final title = json['title'] as String;
    final priority = priorityFromString(json['priority'] as String);
    final dueDate =
        json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null;
    final completed = json['completed'] as bool? ?? false;
    final type = json['type'] as String;

    switch (type) {
      case 'UrgentTask':
        return UrgentTask(id: id, title: title, dueDate: dueDate, completed: completed);
      case 'NormalTask':
      default:
        return NormalTask(
          id: id,
          title: title,
          priority: priority,
          dueDate: dueDate,
          completed: completed,
        );
    }
  }

  @override
  String toString() {
    final statut = completed ? '[x]' : '[ ]';
    final date = dueDate != null
        ? ' (échéance: ${dueDate!.day.toString().padLeft(2, '0')}/'
            '${dueDate!.month.toString().padLeft(2, '0')}/${dueDate!.year})'
        : '';
    return '$statut $title - ${priority.name}$date';
  }
}

class NormalTask extends Task implements Completable {
  NormalTask({
    required super.id,
    required super.title,
    required super.priority,
    super.dueDate,
    super.completed,
  });

  @override
  String get type => 'NormalTask';

  @override
  void markCompleted() {
    completed = true;
  }
}

class UrgentTask extends Task implements Completable {
  UrgentTask({
    required super.id,
    required super.title,
    super.dueDate,
    super.completed,
  }) : super(priority: Priority.high);

  @override
  String get type => 'UrgentTask';

  @override
  void markCompleted() {
    completed = true;
  }

  @override
  String toString() => '🔥 ${super.toString()}';
}

// ============================================================
// REPOSITORY GÉNÉRIQUE + PERSISTANCE JSON
// ============================================================

abstract class Repository<T> {
  void add(T item);
  void remove(String id);
  void update(T item);
  List<T> getAll();
}

class TaskRepository implements Repository<Task> {
  final String filePath;
  final List<Task> _tasks = [];

  TaskRepository(this.filePath) {
    _load();
  }

  void _load() {
    final file = File(filePath);
    if (!file.existsSync()) return;

    final content = file.readAsStringSync();
    if (content.trim().isEmpty) return;

    final List<dynamic> data = jsonDecode(content) as List<dynamic>;
    _tasks.addAll(data.map((e) => Task.fromJson(e as Map<String, dynamic>)));
  }

  void _save() {
    final file = File(filePath);
    final data = _tasks.map((t) => t.toJson()).toList();
    file.writeAsStringSync(jsonEncode(data));
  }

  @override
  void add(Task item) {
    if (item.title.trim().isEmpty) {
      throw EmptyTitleException();
    }
    _tasks.add(item);
    _save();
  }

  @override
  void remove(String id) {
    final existe = _tasks.any((t) => t.id == id);
    if (!existe) throw TaskNotFoundException(id);
    _tasks.removeWhere((t) => t.id == id);
    _save();
  }

  @override
  void update(Task item) {
    final index = _tasks.indexWhere((t) => t.id == item.id);
    if (index == -1) throw TaskNotFoundException(item.id);
    _tasks[index] = item;
    _save();
  }

  @override
  List<Task> getAll() => List.unmodifiable(_tasks);

  Task getById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    throw TaskNotFoundException(id);
  }

  List<Task> sortedByPriority() {
    final copie = List<Task>.from(_tasks);
    copie.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    return copie;
  }

  List<Task> sortedByDate() {
    final copie = List<Task>.from(_tasks);
    copie.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
    return copie;
  }
}

// ============================================================
// POINT D'ENTRÉE
//   - Sans argument : menu interactif
//   - Avec arguments : add / list / complete / delete
// ============================================================

late final TaskRepository repo;
int _compteur = 0;

String genererId() {
  _compteur++;
  return '${DateTime.now().millisecondsSinceEpoch}_$_compteur';
}

void main(List<String> args) {
  repo = TaskRepository('taches.json');

  if (args.isEmpty) {
    lancerMenuInteractif();
    return;
  }

  try {
    executerCommande(args);
  } on TaskException catch (e) {
    stderr.writeln('Erreur : $e');
    exit(1);
  }
}

// ---------------- MODE COMMANDE ----------------

String? getOption(List<String> args, String nom) {
  final index = args.indexOf('--$nom');
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

bool hasFlag(List<String> args, String nom) => args.contains('--$nom');

void executerCommande(List<String> args) {
  final commande = args[0];

  switch (commande) {
    case 'add':
      commandeAdd(args);
      break;
    case 'list':
      commandeList(args);
      break;
    case 'complete':
      commandeComplete(args);
      break;
    case 'delete':
      commandeDelete(args);
      break;
    case 'help':
    case '--help':
    case '-h':
      afficherAide();
      break;
    default:
      print('Commande inconnue: "$commande". Tape "help" pour voir les commandes disponibles.');
  }
}

void commandeAdd(List<String> args) {
  if (args.length < 2) {
    print('Usage: add "<titre>" [--priority low|medium|high] [--due jj/mm/aaaa] [--urgent]');
    return;
  }
  final titre = args[1];
  final urgent = hasFlag(args, 'urgent');
  final dueStr = getOption(args, 'due');
  final dueDate = dueStr != null ? parseDate(dueStr) : null;

  final id = genererId();
  Task tache;

  if (urgent) {
    tache = UrgentTask(id: id, title: titre, dueDate: dueDate);
  } else {
    final prioStr = getOption(args, 'priority') ?? 'medium';
    final priorite = priorityFromString(prioStr);
    tache = NormalTask(id: id, title: titre, priority: priorite, dueDate: dueDate);
  }

  repo.add(tache);
  print('Tâche ajoutée (id: $id).');
}

void commandeList(List<String> args) {
  final tri = getOption(args, 'sort');
  final taches = tri == 'date' ? repo.sortedByDate() : repo.sortedByPriority();
  afficherListe(taches);
}

void commandeComplete(List<String> args) {
  if (args.length < 2) {
    print('Usage: complete <id>');
    return;
  }
  final tache = repo.getById(args[1]);
  if (tache is Completable) {
    (tache as Completable).markCompleted();
  }
  repo.update(tache);
  print('Tâche marquée comme terminée.');
}

void commandeDelete(List<String> args) {
  if (args.length < 2) {
    print('Usage: delete <id>');
    return;
  }
  repo.remove(args[1]);
  print('Tâche supprimée.');
}

void afficherAide() {
  print('''
Gestionnaire de tâches - commandes disponibles :

  add "<titre>" [--priority low|medium|high] [--due jj/mm/aaaa] [--urgent]
  list [--sort priority|date]
  complete <id>
  delete <id>
  (sans argument) -> menu interactif

Exemples :
  dart run lib/main.dart add "Réviser Dart" --priority high --due 24/12/2026
  dart run lib/main.dart list --sort date
  dart run lib/main.dart complete 1699999999_1
  dart run lib/main.dart delete 1699999999_1
''');
}

void afficherListe(List<Task> taches) {
  if (taches.isEmpty) {
    print('Aucune tâche pour le moment.');
    return;
  }
  for (final t in taches) {
    print('${t.id} | $t');
  }
}

// ---------------- MODE INTERACTIF ----------------

void lancerMenuInteractif() {
  bool continuer = true;
  while (continuer) {
    print('\n===== Gestionnaire de tâches =====');
    print('1. Ajouter une tâche');
    print('2. Lister les tâches (par priorité)');
    print('3. Lister les tâches (par date)');
    print('4. Marquer une tâche comme terminée');
    print('5. Supprimer une tâche');
    print('6. Quitter');
    stdout.write('Choix : ');
    final choix = stdin.readLineSync();

    try {
      switch (choix) {
        case '1':
          ajouterTacheInteractif();
          break;
        case '2':
          afficherListe(repo.sortedByPriority());
          break;
        case '3':
          afficherListe(repo.sortedByDate());
          break;
        case '4':
          marquerTermineeInteractif();
          break;
        case '5':
          supprimerTacheInteractif();
          break;
        case '6':
          continuer = false;
          break;
        default:
          print('Choix invalide, réessaie.');
      }
    } on TaskException catch (e) {
      print('Erreur : $e');
    }
  }

  print('Au revoir !');
}

void ajouterTacheInteractif() {
  stdout.write('Titre : ');
  final titre = stdin.readLineSync() ?? '';

  stdout.write('Tâche urgente ? (o/n) : ');
  final urgent = (stdin.readLineSync() ?? '').trim().toLowerCase() == 'o';

  stdout.write('Date limite (jj/mm/aaaa) ou vide : ');
  final dateSaisie = stdin.readLineSync();
  DateTime? dateLimite;
  if (dateSaisie != null && dateSaisie.trim().isNotEmpty) {
    dateLimite = parseDate(dateSaisie.trim());
  }

  final id = genererId();
  Task tache;

  if (urgent) {
    tache = UrgentTask(id: id, title: titre, dueDate: dateLimite);
  } else {
    stdout.write('Priorité (low/medium/high) : ');
    final prioSaisie = stdin.readLineSync() ?? '';
    final priorite = priorityFromString(prioSaisie);
    tache = NormalTask(id: id, title: titre, priority: priorite, dueDate: dateLimite);
  }

  repo.add(tache);
  print('Tâche ajoutée (id: $id).');
}

void marquerTermineeInteractif() {
  stdout.write('Id de la tâche à marquer comme terminée : ');
  final id = stdin.readLineSync() ?? '';

  final tache = repo.getById(id);
  if (tache is Completable) {
    (tache as Completable).markCompleted();
  }
  repo.update(tache);
  print('Tâche marquée comme terminée.');
}

void supprimerTacheInteractif() {
  stdout.write('Id de la tâche à supprimer : ');
  final id = stdin.readLineSync() ?? '';

  repo.remove(id);
  print('Tâche supprimée.');
}