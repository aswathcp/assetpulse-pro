import 'package:material_ui/material_ui.dart';
import '../services/ai_fault_log_service.dart';
import '../services/gemini_model_service.dart';

/// Shows the shared Gemini AI Settings dialog with automatic best-free-model
/// discovery, manual model override, and API key configuration.
Future<void> showGeminiSettingsDialog(
  BuildContext context, {
  Future<void> Function()? onUpdated,
}) async {
  final aiService = AiFaultLogService();
  final modelService = GeminiModelService();

  final isDevKey = await aiService.isUsingDeveloperKey();
  final savedKey = isDevKey ? '' : (await aiService.getApiKey() ?? '');
  final devEnabled = await aiService.getDeveloperKeyEnabled();
  final activeKey = await aiService.getApiKey();
  String? manualModel = await modelService.getManualModel();
  List<GeminiModelInfo> discoveredModels =
      (activeKey != null && activeKey.isNotEmpty)
          ? await modelService.discoverBestFreeModels(activeKey)
          : [];

  if (!context.mounted) return;

  final controller = TextEditingController(text: savedKey);
  bool localDevEnabled = devEnabled;
  bool isScanningModels = false;
  String? scanStatus;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final effectiveKey = controller.text.trim().isNotEmpty
            ? controller.text.trim()
            : (localDevEnabled ? (activeKey ?? '') : '');

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gemini AI & Model Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'Auto-detects the best free-tier Gemini model for your key (preferring fast Flash models with high free quotas) and falls back cleanly if rate-limited.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                if (isDevKey) ...[
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Use Developer Shared Key',
                      style: TextStyle(fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Enable Gemini AI without a personal key',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: localDevEnabled,
                    activeThumbColor: Colors.greenAccent,
                    onChanged: (v) => setDialogState(() => localDevEnabled = v),
                  ),
                  const Divider(),
                ],
                const Text(
                  'Your Personal API Key (optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Google Gemini API Key',
                    hintText: 'AIzaSy... (from aistudio.google.com)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Best Free Model Selection',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isScanningModels || effectiveKey.isEmpty
                          ? null
                          : () async {
                              setDialogState(() {
                                isScanningModels = true;
                                scanStatus = null;
                              });
                              final found =
                                  await modelService.discoverBestFreeModels(
                                effectiveKey,
                                forceRefresh: true,
                              );
                              if (!ctx.mounted) return;
                              setDialogState(() {
                                discoveredModels = found;
                                isScanningModels = false;
                                scanStatus = found.isNotEmpty
                                    ? 'Best free model: ${found.first.id}'
                                    : 'Could not reach API; using defaults.';
                              });
                            },
                      icon: isScanningModels
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.radar, size: 16),
                      label: const Text(
                        'Find Best',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: (manualModel != null &&
                          discoveredModels.any((m) => m.id == manualModel))
                      ? manualModel
                      : '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: '',
                      child: Text(
                        discoveredModels.isNotEmpty
                            ? 'Auto (Best Free: ${discoveredModels.first.id})'
                            : 'Auto (Best Free Model)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...discoveredModels.map(
                      (m) => DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(
                          '${m.id} (${m.tierNote})',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() {
                    manualModel = (val == null || val.isEmpty) ? null : val;
                  }),
                ),
                if (scanStatus != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    scanStatus!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (savedKey.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await aiService.saveApiKey('');
                  await aiService.setDeveloperKeyEnabled(true);
                  await modelService.setManualModel(null);
                  if (onUpdated != null) await onUpdated();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Personal key cleared. Switched to developer key.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Clear Key',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final newKey = controller.text.trim();
                await aiService.saveApiKey(newKey);
                await aiService.setDeveloperKeyEnabled(localDevEnabled);
                await modelService.setManualModel(manualModel);
                if (onUpdated != null) await onUpdated();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  final msg = newKey.isNotEmpty
                      ? 'Gemini API Key & model settings saved!'
                      : localDevEnabled
                          ? 'Using shared Developer Key & auto model selection.'
                          : 'AI key cleared. Using Offline NLP mode.';
                  messenger.showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Save & Apply'),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
}
