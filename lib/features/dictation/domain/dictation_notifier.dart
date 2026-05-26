import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

class DiffResult {
  final String original;
  final String userInput;
  final List<Diff> diffs;

  DiffResult({required this.original, required this.userInput, required this.diffs});
}

class DictationState {
  final String originalText;
  final String userInput;
  final DiffResult? diffResult;
  final bool submitted;

  const DictationState({
    this.originalText = '',
    this.userInput = '',
    this.diffResult,
    this.submitted = false,
  });

  DictationState copyWith({String? originalText, String? userInput, DiffResult? diffResult, bool? submitted}) {
    return DictationState(
      originalText: originalText ?? this.originalText,
      userInput: userInput ?? this.userInput,
      diffResult: diffResult ?? this.diffResult,
      submitted: submitted ?? this.submitted,
    );
  }
}

final dictationProvider = NotifierProvider<DictationNotifier, DictationState>(
  DictationNotifier.new,
);

class DictationNotifier extends Notifier<DictationState> {
  @override
  DictationState build() => const DictationState();

  void setOriginalText(String text) {
    state = state.copyWith(originalText: text, submitted: false, diffResult: null);
  }

  void updateUserInput(String input) {
    state = state.copyWith(userInput: input);
  }

  void submit() {
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(state.originalText, state.userInput);
    state = state.copyWith(
      diffResult: DiffResult(
        original: state.originalText,
        userInput: state.userInput,
        diffs: diffs,
      ),
      submitted: true,
    );
  }

  void reset() {
    state = const DictationState();
  }
}
