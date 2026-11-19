// enum InspectionQuestionType { yesNo, text, dropdown, datepicker }

// class InspectionQuestion {
//   final String code;
//   final String text;
//   final InspectionQuestionType type;
//   final String? hint;
//   final List<String>? options;

//   const InspectionQuestion({
//     required this.code,
//     required this.text,
//     this.type = InspectionQuestionType.yesNo,
//     this.hint,
//     this.options,
//   });
// }

// class InspectionSection {
//   final String title;
//   final List<InspectionQuestion> questions;

//   const InspectionSection({required this.title, required this.questions});
// }

enum InspectionQuestionType { yesNo, text, dropdown, datepicker }

enum AiAnalysisType { none, roadDefect }

class InspectionQuestion {
  final String code;
  final String text;
  final InspectionQuestionType type;
  final String? hint;
  final List<String>? options;
  final AiAnalysisType aiAnalysisType;

  const InspectionQuestion({
    required this.code,
    required this.text,
    this.type = InspectionQuestionType.yesNo,
    this.hint,
    this.options,
    this.aiAnalysisType = AiAnalysisType.none,
  });
}

class InspectionSection {
  final String title;
  final List<InspectionQuestion> questions;

  const InspectionSection({required this.title, required this.questions});
}