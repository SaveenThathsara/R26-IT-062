import 'package:flutter/foundation.dart';
import 'inference_service.dart';

/// Singleton that owns the [InferenceService] lifetime.
/// Exposes a [ValueNotifier] so UI can react to initialization state.
///
/// Usage:
///   final svc = ModelInitializer.instance.service;
class ModelInitializer {
  ModelInitializer._();
  static final instance = ModelInitializer._();

  final InferenceService service = InferenceService();

  final ValueNotifier<ModelState> state =
      ValueNotifier(ModelState.idle);

  String? errorMessage;

  Future<void> ensureReady() async {
    if (state.value == ModelState.ready) return;
    if (state.value == ModelState.loading) return;

    state.value = ModelState.loading;
    try {
      await service.initialize();
      state.value = ModelState.ready;
    } catch (e) {
      errorMessage = e.toString();
      state.value = ModelState.error;
    }
  }
}

enum ModelState { idle, loading, ready, error }
