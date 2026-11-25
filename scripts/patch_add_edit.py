import os

path = 'lib/features/admin/presentation/pages/add_edit_hierarchy_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the collection-specific fields for fault_types and odc_causes
target_block = '''    } else if (widget.collection == 'fault_types') {
      final currentCategory = _formData['category'] ?? 'Electrical';
      final currentEqType = _formData['equipmentType'] ?? 'All';

      const eqTypes = [
        'All', 'Motor', 'Pump', 'Transformer', 'Panel / Switchboard', 'Feeder / Breaker',
        'Gearbox', 'Compressor', 'Fan / Blower', 'Conveyor', 'Crusher', 'Crane', 'Valve / Actuator', 'Other'
      ];

      return [
        SearchableSelectionField<String>(
          label: 'Fault Discipline / Category',
          hintText: 'Select category',
          selectedValue: currentCategory,
          prefixIcon: Icons.category,
          items: faultCategories.map((c) => SearchableItem<String>(value: c, label: c)).toList(),
          onChanged: (v) => setState(() => _formData['category'] = v ?? 'Electrical'),
        ),
        const SizedBox(height: 14),

        SearchableSelectionField<String>(
          label: 'Applicable Equipment Type',
          hintText: 'Select equipment applicability',
          selectedValue: currentEqType,
          prefixIcon: Icons.precision_manufacturing,
          items: eqTypes.map((t) => SearchableItem<String>(value: t, label: t)).toList(),
          onChanged: (v) => setState(() => _formData['equipmentType'] = v ?? 'All'),
        ),
      ];
    } else if (widget.collection == 'odc_causes') {
      final currentCategory = _formData['category'] ?? 'Wear & Tear';

      return [
        SearchableSelectionField<String>(
          label: 'Root Cause Category',
          hintText: 'Select damage root cause category',
          selectedValue: currentCategory,
          prefixIcon: Icons.psychology,
          items: odcCategories.map((c) => SearchableItem<String>(value: c, label: c)).toList(),
          onChanged: (v) => setState(() => _formData['category'] = v ?? 'Wear & Tear'),
        ),
      ];
    }'''

replacement_block = '''    } else if (widget.collection == 'fault_types') {
      final currentDiscipline = _formData['discipline'] ?? _formData['category'] ?? 'Electrical';
      final currentEqType = _formData['targetEquipment'] ?? _formData['equipmentType'] ?? 'Contactor / Starter';
      final currentSev = _formData['severity'] ?? 'Major';

      const eqTypes = [
        'Contactor / Starter', 'Brakes & Thrusters', 'VFD / Variable Speed Drive', 'Soft Starter',
        'DOL / Star-Delta Starter', 'Air Circuit Breaker (ACB)', 'MCCB / Switchgear', 'Electric Motor',
        'Power / Distribution Transformer', 'Centrifugal / Slurry Pump', 'Industrial Gearbox',
        'Belt Conveyor / Drive', 'Control Valve / Actuator', 'Transmitter / Sensor', 'PLC / Controller', 'Other'
      ];
      const severities = ['Critical', 'Major', 'Moderate', 'Minor'];

      return [
        SearchableSelectionField<String>(
          label: 'Engineering Discipline',
          selectedValue: currentDiscipline,
          prefixIcon: Icons.engineering,
          items: ['Electrical', 'Mechanical', 'Instrumentation'].map((c) => SearchableItem<String>(value: c, label: c)).toList(),
          onChanged: (v) => setState(() {
            _formData['discipline'] = v ?? 'Electrical';
            _formData['category'] = v ?? 'Electrical';
          }),
        ),
        const SizedBox(height: 14),
        SearchableSelectionField<String>(
          label: 'Target Equipment Component',
          selectedValue: currentEqType,
          prefixIcon: Icons.precision_manufacturing,
          items: eqTypes.map((t) => SearchableItem<String>(value: t, label: t)).toList(),
          onChanged: (v) => setState(() {
            _formData['targetEquipment'] = v ?? 'Contactor / Starter';
            _formData['equipmentType'] = v ?? 'Contactor / Starter';
          }),
        ),
        const SizedBox(height: 14),
        SearchableSelectionField<String>(
          label: 'Default Severity',
          selectedValue: currentSev,
          prefixIcon: Icons.warning_amber_rounded,
          items: severities.map((s) => SearchableItem<String>(value: s, label: s)).toList(),
          onChanged: (v) => setState(() => _formData['severity'] = v ?? 'Major'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: (_formData['targetSlaHours'] ?? 4).toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target Resolution SLA (Hours)',
            prefixIcon: Icon(Icons.timer_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _formData['targetSlaHours'] = int.tryParse(v.trim()) ?? 4,
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: _formData['diagnosticChecks']?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Diagnostic Checks / Testing Guide',
            hintText: 'e.g. Check coil resistance, verify auxiliary contact closure...',
            prefixIcon: Icon(Icons.troubleshoot, size: 20),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (v) => _formData['diagnosticChecks'] = v.trim(),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: _formData['correctiveAction']?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Standard Corrective Action',
            hintText: 'e.g. Clean contact surfaces, replace burnt coil assembly...',
            prefixIcon: Icon(Icons.build_circle_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (v) => _formData['correctiveAction'] = v.trim(),
        ),
      ];
    } else if (widget.collection == 'odc_causes') {
      final currentDiscipline = _formData['discipline'] ?? _formData['category'] ?? 'Electrical';
      final currentEq = _formData['equipmentCategory'] ?? 'Contactor';
      final currentSev = _formData['severity'] ?? 'Major';

      const commonEqs = [
        'Contactor', 'Brakes', 'VFD', 'Soft Starter', 'Star-Delta Starter', 'DOL Starter',
        'Circuit Breaker', 'Motor', 'Transformer', 'Pump', 'Gearbox', 'Conveyor', 'Valve', 'Transmitter', 'PLC'
      ];
      const severities = ['Critical', 'Major', 'Moderate', 'Minor'];

      return [
        SearchableSelectionField<String>(
          label: 'Engineering Discipline',
          selectedValue: currentDiscipline,
          prefixIcon: Icons.engineering,
          items: ['Electrical', 'Mechanical', 'Instrumentation'].map((c) => SearchableItem<String>(value: c, label: c)).toList(),
          onChanged: (v) => setState(() {
            _formData['discipline'] = v ?? 'Electrical';
            _formData['category'] = v ?? 'Electrical';
          }),
        ),
        const SizedBox(height: 14),
        SearchableSelectionField<String>(
          label: 'Equipment Category',
          selectedValue: currentEq,
          prefixIcon: Icons.precision_manufacturing,
          items: commonEqs.map((e) => SearchableItem<String>(value: e, label: e)).toList(),
          onChanged: (v) => setState(() => _formData['equipmentCategory'] = v ?? 'Contactor'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: _formData['objectPart']?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Component / Object Part *',
            hintText: 'e.g. Main Contacts, Brake Lining, IGBT Module, DE Bearing...',
            prefixIcon: Icon(Icons.extension_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Object Part is required' : null,
          onChanged: (v) => _formData['objectPart'] = v.trim(),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: _formData['damage']?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Defect / Damage Mode *',
            hintText: 'e.g. Pitting & Carbonisation, Lining Wear, High Vibration...',
            prefixIcon: Icon(Icons.broken_image_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Damage Mode is required' : null,
          onChanged: (v) => _formData['damage'] = v.trim(),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: _formData['cause']?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Root Cause / Failure Mechanism *',
            hintText: 'e.g. Heavy Inrush Current Arcing, Overload, Moisture Ingress...',
            prefixIcon: Icon(Icons.psychology_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Root Cause is required' : null,
          onChanged: (v) => _formData['cause'] = v.trim(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _formData['isoCode']?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'ISO 14224 Code',
                  hintText: 'e.g. EL-CON-01',
                  prefixIcon: Icon(Icons.confirmation_number_outlined, size: 20),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _formData['isoCode'] = v.trim(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchableSelectionField<String>(
                label: 'Severity Level',
                selectedValue: currentSev,
                prefixIcon: Icons.warning_amber_rounded,
                items: severities.map((s) => SearchableItem<String>(value: s, label: s)).toList(),
                onChanged: (v) => setState(() => _formData['severity'] = v ?? 'Major'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: _formData['recommendedAction']?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Recommended Action / Maintenance Remedy',
            hintText: 'e.g. Clean contact surfaces, replace brake pads, torque bolts...',
            prefixIcon: Icon(Icons.handyman_outlined, size: 20),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (v) => _formData['recommendedAction'] = v.trim(),
        ),
      ];
    }'''

if target_block in content:
    content = content.replace(target_block, replacement_block)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('SUCCESS')
else:
    print('TARGET_NOT_FOUND')
