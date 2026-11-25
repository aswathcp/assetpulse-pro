import 'package:flutter/material.dart';

/// MemoryOptimizationService enforces Android latest memory policies:
/// - Controls maximum dynamic bitmap cache allocation in memory.
/// - Evicts decoded bitmaps when the app moves to background/hidden states,
///   complying with Google Play's Bitmap Memory Bad Behavior Threshold.
/// - Responds to system memory pressure (`didHaveMemoryPressure` / `onTrimMemory`)
///   to prevent OS termination under the Android Memory Limiter.
class MemoryOptimizationService with WidgetsBindingObserver {
  static final MemoryOptimizationService _instance = MemoryOptimizationService._internal();
  factory MemoryOptimizationService() => _instance;
  MemoryOptimizationService._internal();

  bool _initialized = false;

  /// Initializes image cache caps and lifecycle memory trimming listeners.
  static void initialize() {
    _instance._init();
  }

  void _init() {
    if (_initialized) return;
    _initialized = true;

    final imageCache = PaintingBinding.instance.imageCache;
    // Set conservative budget: 40MB max decoded bitmap cache, 80 image entries
    imageCache.maximumSizeBytes = 40 * 1024 * 1024;
    imageCache.maximumSize = 80;

    WidgetsBinding.instance.addObserver(this);
    debugPrint('[MemoryOptimization] Initialized with 40MB image cache limit.');
  }

  @override
  void didHaveMemoryPressure() {
    // OS is experiencing high memory pressure. Release cached bitmaps immediately.
    debugPrint('[MemoryOptimization] System memory pressure detected. Evicting caches.');
    _evictBitmaps();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // App entered background or is non-visible. Comply with Google Play policy:
      // Bitmaps must not be held in memory for extended periods in non-visible states.
      debugPrint('[MemoryOptimization] App backgrounded. Clearing non-visible bitmap caches.');
      _evictBitmaps();
    }
  }

  void _evictBitmaps() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
  }
}
