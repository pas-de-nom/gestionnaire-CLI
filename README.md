# Gestionnaire de tâches CLI

Application en ligne de commande écrite en Dart pur permettant de gérer des tâches (ajout, liste, complétion, suppression) avec persistance dans un fichier JSON local.

## Prérequis

- [Dart SDK](https://dart.dev/get-dart) installé

Vérifier l'installation :
```bash
dart --version
```

## Structure du projet
tache_cli/
pubspec.yaml
lib/
main.dart
test/
task_test.dart

## Installation

Depuis la racine du projet (là où se trouve `pubspec.yaml`) :

```bash
dart pub get
```

## Lancer l'application

```bash
dart run lib/main.dart
```

Un menu s'affiche dans le terminal :
1/Ajouter une tâche
2/Lister les tâches (par priorité)
3/Lister les tâches (par date)
4/Marquer une tâche comme terminée
5/Supprimer une tâche
6/Quitter 

## utilisation
Tape le numéro correspondant à ton choix et suis les instructions affichées.

Les tâches sont automatiquement sauvegardées dans un fichier `taches.json`, créé à la racine du projet au premier ajout, et rechargées à chaque redémarrage de l'application.

## Fonctionnalités

- Ajout d'une tâche (titre, priorité `low` / `medium` / `high`, date limite optionnelle au format jj/mm/aaaa)
- Ajout d'une tâche urgente (priorité automatiquement fixée à `high`)
- Liste des tâches triées par priorité ou par date
- Marquage d'une tâche comme terminée
- Suppression d'une tâche
- Persistance automatique dans `taches.json`

## Lancer les tests

```bash
dart test
```