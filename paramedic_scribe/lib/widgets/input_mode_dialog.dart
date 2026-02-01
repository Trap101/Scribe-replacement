import 'package:flutter/material.dart';

class InputModeDialog extends StatefulWidget {
  final bool hasConnection;
  final Function(String) onTextInput;
  final VoidCallback onVoiceInput;

  const InputModeDialog({
    super.key,
    required this.hasConnection,
    required this.onTextInput,
    required this.onVoiceInput,
  });

  @override
  State<InputModeDialog> createState() => _InputModeDialogState();
}

class _InputModeDialogState extends State<InputModeDialog> {
  final _textController = TextEditingController();
  bool _showTextInput = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showTextInput) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Describe Patient Situation',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI will extract relevant details and auto-fill the form',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: 8,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Example: 65-year-old male, chest pain for 30 minutes, history of diabetes and hypertension, BP 150/95, pulse 88...',
                    hintStyle: TextStyle(
                      color: Colors.black.withOpacity(0.35),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _showTextInput = false),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _textController.text.trim().isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            widget.onTextInput(_textController.text);
                          },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Process with AI'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.input_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Choose Input Method',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            if (!widget.hasConnection) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Color(0xFFE65100), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No internet connection - AI features unavailable',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            _ModeButton(
              icon: Icons.keyboard_rounded,
              label: 'Manual Entry',
              subtitle: 'Fill in each field individually',
              gradient: const LinearGradient(
                colors: [Color(0xFF37474F), Color(0xFF546E7A)],
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            _ModeButton(
              icon: Icons.edit_note_rounded,
              label: 'Type & AI Auto-fill',
              subtitle: 'Describe situation, AI fills the form',
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              ),
              enabled: widget.hasConnection,
              onTap: () => setState(() => _showTextInput = true),
            ),
            const SizedBox(height: 12),
            _ModeButton(
              icon: Icons.mic_rounded,
              label: 'Speak & AI Auto-fill',
              subtitle: 'Voice transcribed and processed by AI',
              gradient: const LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFFE57373)],
              ),
              enabled: widget.hasConnection,
              onTap: () {
                Navigator.pop(context);
                widget.onVoiceInput();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: enabled ? gradient : null,
              color: enabled ? null : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
