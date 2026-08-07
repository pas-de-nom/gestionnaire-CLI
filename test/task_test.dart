import 'dart:io';
import 'package:test/test.dart';
import 'package:tache_cli/main.dart';

void main() {
  const testFile = 'test_taches.json';
  late TaskRepository repo;

  setUp(() {
    final f = File(testFile);
    if (f.existsSync()) f.deleteSync();
    repo = TaskRepository(testFile);
  });

  tearDown(() {
    final f = File(testFile);
    if (f.existsSync()) f.deleteSync();
  });

  test('ajouter une tâche la fait apparaître dans getAll()', () {
    repo.add(NormalTask(id: '1', title: 'Réviser Dart', priority: Priority.medium));
    expect(repo.getAll().length, 1);
  });

  test('ajouter une tâche au titre vide lève EmptyTitleException', () {
    final t = NormalTask(id: '2', title: '   ', priority: Priority.low);
    expect(() => repo.add(t), throwsA(isA<EmptyTitleException>()));
  });

  test('supprimer une tâche existante la retire de la liste', () {
    repo.add(NormalTask(id: '3', title: 'Courses', priority: Priority.low));
    repo.remove('3');
    expect(repo.getAll(), isEmpty);
  });

  test('supprimer une tâche inexistante lève TaskNotFoundException', () {
    expect(() => repo.remove('inconnu'), throwsA(isA<TaskNotFoundException>()));
  });

  test('marquer une tâche comme terminée met completed à true', () {
    repo.add(NormalTask(id: '4', title: 'Loyer', priority: Priority.high));
    final t = repo.getById('4');
    if (t is Completable) (t as Completable).markCompleted();
    repo.update(t);
    expect(repo.getById('4').completed, isTrue);
  });

  test('sortedByPriority() trie du plus prioritaire au moins prioritaire', () {
    repo.add(NormalTask(id: 'a', title: 'A', priority: Priority.low));
    repo.add(NormalTask(id: 'b', title: 'B', priority: Priority.high));
    repo.add(NormalTask(id: 'c', title: 'C', priority: Priority.medium));
    expect(repo.sortedByPriority().map((t) => t.id).toList(), ['b', 'c', 'a']);
  });

  test('une UrgentTask reste UrgentTask après rechargement JSON', () {
    repo.add(UrgentTask(id: 'u1', title: 'Urgence'));
    final repo2 = TaskRepository(testFile);
    expect(repo2.getById('u1'), isA<UrgentTask>());
  });

  test('priorityFromString rejette une valeur invalide', () {
    expect(() => priorityFromString('urgentissime'), throwsA(isA<InvalidPriorityException>()));
  });
}