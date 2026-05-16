class Lesson {
  final String id;
  final String title;
  final String description;
  final String content;
  final String icon;
  final int points;
  final List<String> keyTakeaways;
  final List<String> practiceTasks;
  final List<String> caseStudies;
  final List<String> mythBusters;
  final List<String> templates;
  final List<String> calculators;
  final List<String> applicationTools;
  final String localExample;

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.icon,
    required this.points,
    this.keyTakeaways = const [],
    this.practiceTasks = const [],
    this.caseStudies = const [],
    this.mythBusters = const [],
    this.templates = const [],
    this.calculators = const [],
    this.applicationTools = const [],
    this.localExample = '',
  });
}
