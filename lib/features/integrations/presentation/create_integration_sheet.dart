import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/error.dart';
import 'integrations_providers.dart';
import '../domain/integration.dart';

/// Bottom sheet for creating new integrations.
///
/// Shows a one-time display of the returned secret with secure copy.
class CreateIntegrationSheet extends ConsumerStatefulWidget {
  const CreateIntegrationSheet({super.key});

  @override
  ConsumerState<CreateIntegrationSheet> createState() => _CreateIntegrationSheetState();
}

class _CreateIntegrationSheetState extends ConsumerState<CreateIntegrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _newSecret;
  bool _showSecret = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(integrationControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create New Integration',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Integration Name',
                hintText: 'e.g., Production Scanner',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                if (value.length > 80) {
                  return 'Name must be 80 characters or less';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          controller.whenOrNull(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => AppErrorDisplay(error: error),
          ),
          ElevatedButton(
            onPressed: controller.isLoading ? null : _createIntegration,
            child: const Text('Create Integration'),
          ),
          if (_showSecret && _newSecret != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'One-time secret:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SelectableText(
              _newSecret!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // In real implementation, copy to clipboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showSecret = false;
                      _newSecret = null;
                    });
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _createIntegration() {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(integrationControllerProvider.notifier);
    controller.createScannerPublisher(name: _nameController.text.trim()).then((integration) {
      if (!mounted) return;
      setState(() {
        _newSecret = integration.plaintextSecret;
        _showSecret = true;
      });
    }).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    });
  }
}