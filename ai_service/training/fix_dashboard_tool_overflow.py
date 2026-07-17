from datetime import datetime
from pathlib import Path
import shutil


path = Path(
    r"E:\project 3\MindPulse-AI\mobile_app"
    r"\lib\features\dashboard\screens"
    r"\main_dashboard_screen.dart"
)

if not path.exists():
    raise RuntimeError(
        "Dashboard file was not found."
    )

backup = path.with_name(
    "main_dashboard_screen."
    + datetime.now().strftime(
        "%Y%m%d_%H%M%S"
    )
    + ".before_overflow_fix.dart"
)

shutil.copy2(path, backup)

text = path.read_text(
    encoding="utf-8",
)

old = '''              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE5E4EE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EFFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      tool.icon,
                      color: const Color(0xFF6059E8),
                      size: 30,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    tool.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tool.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF85859A),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),'''

new = '''              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0xFFE5E4EE),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxHeight < 150;

                  if (compact) {
                    return Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF0EFFF),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Icon(
                            tool.icon,
                            color:
                                const Color(0xFF6059E8),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                tool.title,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    const TextStyle(
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tool.subtitle,
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    const TextStyle(
                                      color:
                                          Color(0xFF85859A),
                                      fontSize: 12,
                                      height: 1.25,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF0EFFF),
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: Icon(
                          tool.icon,
                          color:
                              const Color(0xFF6059E8),
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tool.title,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tool.subtitle,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                              Color(0xFF85859A),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
              ),'''

if old not in text:
    raise RuntimeError(
        "Expected dashboard card block "
        "was not found. No file was changed."
    )

text = text.replace(
    old,
    new,
    1,
)

path.write_text(
    text,
    encoding="utf-8",
)

print(
    "Dashboard tool-card overflow fixed successfully."
)

print(
    f"Backup created: {backup}"
)
