class RecitationAssessment {final double recallScore;final List<String> issues;const RecitationAssessment({required this.recallScore,required this.issues});}
abstract class RecitationAssessor {Future<RecitationAssessment> assess({required int ayahId,required String expectedText,required String audioPath});}
/// Provider-neutral boundary. V1 remains functional without an AI service.
class DisabledRecitationAssessor implements RecitationAssessor {Future<RecitationAssessment> assess({required int ayahId,required String expectedText,required String audioPath}) async=>const RecitationAssessment(recallScore:0,issues:['AI recitation assessment is not configured yet.']);}
