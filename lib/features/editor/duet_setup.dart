import 'color_grade.dart';

/// What the editor needs to finish a duet: the top part's filter and how
/// loud the reel is.
class DuetSetup {
  const DuetSetup({this.grade = const ColorGrade(), this.reelVolume = 1});
  final ColorGrade grade;
  final double reelVolume;
}
