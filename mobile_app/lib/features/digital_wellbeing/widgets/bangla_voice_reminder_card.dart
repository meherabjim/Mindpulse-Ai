import 'package:flutter/material.dart';

import '../services/screen_time_service.dart';

class BanglaVoiceReminderCard extends StatefulWidget {
  const BanglaVoiceReminderCard({super.key});

  @override
  State<BanglaVoiceReminderCard> createState() =>
      _BanglaVoiceReminderCardState();
}

class _BanglaVoiceReminderCardState extends State<BanglaVoiceReminderCard> {
  final ScreenTimeService _service = ScreenTimeService();

  bool _loading = true;
  bool _enabled = false;
  bool _testing = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final enabled = await _service.isBanglaVoiceReminderEnabled();

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = enabled;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _setEnabled(bool value) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _service.setBanglaVoiceReminderEnabled(value);

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = value;
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'বাংলা ভয়েস রিমাইন্ডার চালু হয়েছে।'
                : 'বাংলা ভয়েস রিমাইন্ডার বন্ধ হয়েছে।',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _testVoice() async {
    setState(() {
      _testing = true;
      _errorMessage = null;
    });

    try {
      final success = await _service.testBanglaVoiceReminder();

      if (!mounted) {
        return;
      }

      setState(() {
        _testing = false;

        if (!success) {
          _errorMessage =
              'বাংলা Text-to-Speech voice পাওয়া যায়নি। '
              'ফোনের Speech Services settings থেকে '
              'Bengali voice install করুন।';
        }
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('বাংলা ভয়েস পরীক্ষা সফল হয়েছে।')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _testing = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                const Icon(Icons.volume_up_outlined),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    'Bangla Voice Reminder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(value: _enabled, onChanged: _setEnabled),
              ],
            ),

            const SizedBox(height: 10),

            const Text(
              'Usage limit অতিক্রম করলে MindPulse '
              'notification-এর সঙ্গে বাংলায় কথা বলে '
              'বিরতি নেওয়ার পরামর্শ দেবে।',
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.35),

                borderRadius: BorderRadius.circular(12),
              ),

              child: const Text(
                '“আপনি আজ সামাজিক যোগাযোগমাধ্যমে '
                'অনেক সময় কাটিয়েছেন। এখন ফোনটি '
                'কিছুক্ষণ রেখে বিশ্রাম নিন।”',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),

              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: _testing ? null : _testVoice,

              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.record_voice_over_outlined),

              label: Text(
                _testing ? 'ভয়েস চালানো হচ্ছে...' : 'বাংলা ভয়েস পরীক্ষা করুন',
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Voice reminder ফোনের media volume অনুসরণ করবে। '
              'Silent media volume হলে শব্দ শোনা যাবে না।',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
