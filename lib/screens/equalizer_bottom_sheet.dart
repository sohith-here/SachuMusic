import 'package:flutter/material.dart';

import '../services/equalizer_service.dart';

class EqualizerBottomSheet extends StatelessWidget {
  const EqualizerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final service = EqualizerService.instance;

    return ValueListenableBuilder<int>(
      valueListenable: service.changes,
      builder: (context, _, child) {
        final isSupported = service.isSupported;
        final isEnabled = isSupported && service.enabled;
        final gains = service.gains;
        final frequencies = service.formattedFrequencies;
        final minDb = service.minDecibels;
        final maxDb = service.maxDecibels;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: Title & Reset Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Equalizer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isEnabled ? () => service.reset() : null,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Platform Limitation Notice on Windows/non-Android
                if (!isSupported)
                  Card(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Audio Equalizer is supported on Android devices only.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Master Enable Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enable Equalizer',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: service.enabled,
                  onChanged: isSupported
                      ? (value) => service.setEnabled(value)
                      : null,
                ),
                const SizedBox(height: 8),

                // Preset Selector
                Row(
                  children: [
                    const Text(
                      'Preset',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<String>(
                        value: service.preset,
                        isExpanded: true,
                        onChanged: isEnabled
                            ? (newPreset) {
                                if (newPreset != null &&
                                    newPreset != 'Custom') {
                                  service.setPreset(newPreset);
                                }
                              }
                            : null,
                        items: EqualizerService.availablePresets.map((preset) {
                          return DropdownMenuItem<String>(
                            value: preset,
                            child: Text(preset),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Five Vertical Sliders
                SizedBox(
                  height: 180,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final gain = index < gains.length ? gains[index] : 0.0;
                      final freq = index < frequencies.length
                          ? frequencies[index]
                          : '';

                      return Expanded(
                        child: Column(
                          children: [
                            // Current Gain
                            Text(
                              '${gain >= 0 ? "+" : ""}${gain.toStringAsFixed(1)} dB',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isEnabled
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Vertical Slider
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                  ),
                                  child: Slider(
                                    value: gain.clamp(minDb, maxDb),
                                    min: minDb,
                                    max: maxDb,
                                    onChanged: isEnabled
                                        ? (val) =>
                                              service.setBandGain(index, val)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Frequency Label
                            Text(
                              freq,
                              style: TextStyle(
                                fontSize: 11,
                                color: isEnabled
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
