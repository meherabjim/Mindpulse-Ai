from pathlib import Path


path = Path(
    r"E:\project 3\MindPulse-AI\mobile_app"
    r"\lib\features\digital_wellbeing"
    r"\screens\mindful_screen_time_screen.dart"
)

text = path.read_text(
    encoding="utf-8"
)


# Add Manage Access card to the enabled screen.
if "_buildManageAccessCard()," not in text:
    old = """                    _buildPrivacyCard(),
                  ],"""

    new = """                    _buildPrivacyCard(),

                    const SizedBox(
                      height: 14,
                    ),

                    _buildManageAccessCard(),
                  ],"""

    if old not in text:
        raise RuntimeError(
            "Enabled screen insertion point was not found."
        )

    text = text.replace(
        old,
        new,
        1,
    )


# Add the Manage Access card widget.
if "Widget _buildManageAccessCard()" not in text:
    marker = "  Widget _buildPrivacyCard() {"

    block = r'''  Widget _buildManageAccessCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            const Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                ),

                SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Manage Usage Access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text(
              'To stop screen-time monitoring, open Android '
              'Usage Access settings, select MindPulse AI, '
              'and turn off Allow usage access.',
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _openPermissionSettings,

              icon: const Icon(
                Icons.settings_outlined,
              ),

              label: const Text(
                'Manage / Turn Off Usage Access',
              ),
            ),
          ],
        ),
      ),
    );
  }


'''

    if marker not in text:
        raise RuntimeError(
            "Privacy card insertion point was not found."
        )

    text = text.replace(
        marker,
        block + marker,
        1,
    )


path.write_text(
    text,
    encoding="utf-8",
)

print(
    "Manage Usage Access button added successfully."
)
