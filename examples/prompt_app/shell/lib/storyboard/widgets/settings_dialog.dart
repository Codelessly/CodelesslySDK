import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:skip_shell/storyboard/services/status_service.dart';

/// Dialog for configuring storyboard settings
class StoryboardSettingsDialog extends StatefulWidget {
  final bool isDarkMode;

  const StoryboardSettingsDialog({
    super.key,
    required this.isDarkMode,
  });

  /// Show the settings dialog
  static Future<void> show(BuildContext context,
      {required bool isDarkMode}) async {
    return showDialog(
      context: context,
      builder: (context) => StoryboardSettingsDialog(isDarkMode: isDarkMode),
    );
  }

  @override
  State<StoryboardSettingsDialog> createState() =>
      _StoryboardSettingsDialogState();
}

class _StoryboardSettingsDialogState extends State<StoryboardSettingsDialog> {
  late TextEditingController _pathController;
  bool _isValidPath = true;
  bool _isLoading = false;
  bool _isValidating = false;
  String? _errorMessage;
  String? _lastValidatedPath;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(
      text: StatusService.instance.currentJsonPath,
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _validatePath(String path) async {
    final trimmedPath = path.trim();

    if (trimmedPath == _lastValidatedPath) return;

    if (trimmedPath.isEmpty) {
      setState(() {
        _isValidPath = true;
        _errorMessage = null;
        _lastValidatedPath = trimmedPath;
      });
      return;
    }

    setState(() => _isValidating = true);
    _lastValidatedPath = trimmedPath;

    try {
      final file = File(trimmedPath);
      final exists = await file.exists();

      if (!mounted) return;

      if (!exists) {
        setState(() {
          _isValidPath = false;
          _errorMessage = 'File does not exist';
          _isValidating = false;
        });
        return;
      }

      final isValid = await StatusService.isValidJsonPath(trimmedPath);

      if (!mounted) return;

      setState(() {
        _isValidPath = isValid;
        _errorMessage =
            isValid ? null : 'Invalid JSON format (missing "statuses" key)';
        _isValidating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidPath = false;
        _errorMessage = 'Error validating path: $e';
        _isValidating = false;
      });
    }
  }

  void _copyCurrentPath() {
    Clipboard.setData(ClipboardData(text: _pathController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Path copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveSettings() async {
    final path = _pathController.text.trim();

    setState(() => _isLoading = true);
    try {
      if (path.isEmpty) {
        await StatusService.instance.setCustomJsonPath(null);
      } else {
        await StatusService.instance.setCustomJsonPath(path);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save settings: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = widget.isDarkMode
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.6);
    final backgroundColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: textColor),
                const SizedBox(width: 12),
                Text(
                  'Storyboard Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Status JSON File Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure where the component status tracking data is stored.',
              style: TextStyle(
                fontSize: 13,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pathController,
              style: TextStyle(color: textColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Default: lib/storyboard/data/storyboard_status.json',
                hintStyle: TextStyle(color: subtitleColor, fontSize: 13),
                filled: true,
                fillColor: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _isValidPath ? Colors.transparent : Colors.red,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.copy, color: subtitleColor, size: 18),
                  onPressed: _copyCurrentPath,
                  tooltip: 'Copy path',
                ),
              ),
              onChanged: _validatePath,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            if (_isValidating)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Validating...',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: subtitleColor)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ||
                          (!_isValidPath && _pathController.text.isNotEmpty)
                      ? null
                      : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
