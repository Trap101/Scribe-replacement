import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/form_field_model.dart';

class FormFieldWidget extends StatelessWidget {
  final FormFieldModel field;
  final VoidCallback onChanged;

  const FormFieldWidget({super.key, required this.field, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accentColor = field.isAiFilled ? const Color(0xFFD32F2F) : const Color(0xFF0D47A1);
    final hasValue = field.value != null && field.value.toString().isNotEmpty && field.value != false;
    return Container(
      decoration: BoxDecoration(
        color: hasValue ? accentColor.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValue ? accentColor.withOpacity(0.2) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: switch (field.type) {
        FieldType.tick => _TickField(field: field, onChanged: onChanged),
        FieldType.dropdown => _DropdownField(field: field, onChanged: onChanged),
        FieldType.number => _NumberField(field: field, onChanged: onChanged),
        FieldType.date => _DateField(field: field, onChanged: onChanged),
        FieldType.time => _TimeField(field: field, onChanged: onChanged),
        FieldType.signature => _SignatureField(field: field, onChanged: onChanged),
        _ => _TextField(field: field, onChanged: onChanged),
      },
    );
  }
}

class _TickField extends StatelessWidget {
  final FormFieldModel field;
  final VoidCallback onChanged;

  const _TickField({required this.field, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        field.value = !(field.value == true);
        field.isAiFilled = false;
        onChanged();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: field.value == true
                    ? const Color(0xFF0D47A1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: field.value == true
                      ? const Color(0xFF0D47A1)
                      : Colors.black.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: field.value == true
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                field.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final FormFieldModel field;
  final VoidCallback onChanged;

  const _DropdownField({required this.field, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.7),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: false,
            ),
            value: (field.options?.contains(field.value) ?? false) ? field.value as String? : null,
            hint: const Text('Select option'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: field.options?.map((o) => DropdownMenuItem(
              value: o,
              child: Text(
                o,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            )).toList(),
            onChanged: (v) {
              field.value = v;
              field.isAiFilled = false;
              onChanged();
            },
            isExpanded: true,
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final FormFieldModel field;
  final VoidCallback onChanged;

  const _NumberField({required this.field, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.7),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: InputDecoration(
            hintText: 'Enter ${field.label.toLowerCase()}',
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.pin_outlined, size: 16, color: Color(0xFF0D47A1)),
            ),
          ),
          keyboardType: TextInputType.number,
          initialValue: field.value?.toString(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          onChanged: (v) {
            field.value = num.tryParse(v);
            field.isAiFilled = false;
            onChanged();
          },
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final FormFieldModel field;
  final VoidCallback onChanged;

  const _TextField({required this.field, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.7),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: InputDecoration(
            hintText: 'Enter ${field.label.toLowerCase()}',
          ),
          initialValue: field.value?.toString(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          maxLines: field.type == FieldType.text ? 4 : 1,
          onChanged: (v) {
            field.value = v;
            field.isAiFilled = false;
            onChanged();
          },
        ),
      ],
    );
  }
}

class _DateField extends StatefulWidget {
  final FormFieldModel field;
  final VoidCallback onChanged;

  const _DateField({required this.field, required this.onChanged});

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.field.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setToday() {
    final now = DateTime.now();
    final formatted = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    setState(() {
      _controller.text = formatted;
      widget.field.value = formatted;
      widget.field.isAiFilled = false;
    });
    widget.onChanged();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final formatted = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      setState(() {
        _controller.text = formatted;
        widget.field.value = formatted;
        widget.field.isAiFilled = false;
      });
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.field.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.7),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  hintText: 'DD/MM/YYYY',
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0D47A1)),
                  ),
                ),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _setToday,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeField extends StatefulWidget {
  final FormFieldModel field;
  final VoidCallback onChanged;

  const _TimeField({required this.field, required this.onChanged});

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.field.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setNow() {
    final now = TimeOfDay.now();
    final formatted = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _controller.text = formatted;
      widget.field.value = formatted;
      widget.field.isAiFilled = false;
    });
    widget.onChanged();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _controller.text = formatted;
        widget.field.value = formatted;
        widget.field.isAiFilled = false;
      });
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.field.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.7),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                readOnly: true,
                onTap: _pickTime,
                decoration: InputDecoration(
                  hintText: 'HH:MM',
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0D47A1)),
                  ),
                ),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _setNow,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignatureField extends StatefulWidget {
  final FormFieldModel field;
  final VoidCallback onChanged;

  const _SignatureField({required this.field, required this.onChanged});

  @override
  State<_SignatureField> createState() => _SignatureFieldState();
}

class _SignatureFieldState extends State<_SignatureField> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _hasSignature = false;

  @override
  void initState() {
    super.initState();
    if (widget.field.value != null && widget.field.value.toString().isNotEmpty) {
      try {
        final data = jsonDecode(widget.field.value as String) as List;
        for (final stroke in data) {
          final points = (stroke as List).map((p) =>
            Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())
          ).toList();
          _strokes.add(points);
        }
        _hasSignature = true;
      } catch (_) {
        _hasSignature = true; // Legacy base64 data - just show as having signature
      }
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _hasSignature = false;
      widget.field.value = null;
      widget.field.isAiFilled = false;
    });
    widget.onChanged();
  }

  void _saveSignature() {
    if (_strokes.isEmpty) return;
    // Store strokes as JSON - lightweight and works on all platforms
    final strokeData = _strokes.map((stroke) =>
      stroke.map((p) => {'x': p.dx, 'y': p.dy}).toList()
    ).toList();
    setState(() {
      widget.field.value = jsonEncode(strokeData);
      widget.field.isAiFilled = false;
      _hasSignature = true;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.field.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.7),
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (_hasSignature || _strokes.isNotEmpty)
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onVerticalDragStart: (_) {},  // Claim vertical drags to prevent ListView scroll
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _strokes.isNotEmpty
                    ? const Color(0xFF0D47A1).withOpacity(0.3)
                    : Colors.black.withOpacity(0.15),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = [details.localPosition];
                    _strokes.add(_currentStroke);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStroke.add(details.localPosition);
                  });
                },
                onPanEnd: (_) {
                  _saveSignature();
                },
                child: CustomPaint(
                  painter: _SignaturePainter(strokes: _strokes),
                  size: const Size(double.infinity, 150),
                  child: _strokes.isEmpty
                      ? Center(
                          child: Text(
                            'Sign here',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.2),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
