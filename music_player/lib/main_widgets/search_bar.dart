import 'package:flutter/material.dart';
import '../theme/cyberpunk_vibrant.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final Function(String) onSubmitted;
  final Function(bool) onFocusChange;

  const SearchBarWidget({
    super.key,
    required this.onFocusChange,
    required this.controller,
    required this.onSearch,
    required this.onSubmitted,
  });

  @override
  _SearchBarWidgetState createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      widget.onFocusChange(_focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: _focusNode.hasFocus
              ? CyberpunkTheme.tyrianPurple.withValues(alpha: 0.95)
              : CyberpunkTheme.brightTurquoise.withValues(alpha: 0.7),
          height: 156,
        ),
        Container(
          width: double.infinity,
          color: CyberpunkTheme.dark.withValues(alpha: 0.95),
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
            top: 25,
            bottom: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              Text(
                'Music App',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: CyberpunkTheme.mainFontColor.withValues(alpha: 0.8),
                ),
              ),
              Text(
                'no ads, no premium, just music --- developed by ap0100',
                style: TextStyle(
                  fontSize: 13,
                  color: CyberpunkTheme.mainFontColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 40,
                child: TextField(
                  focusNode: _focusNode,
                  controller: widget.controller,
                  cursorColor: CyberpunkTheme.turquoiseGreen,
                  onSubmitted: widget.onSubmitted,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: CyberpunkTheme.mainFontColor,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'Search song, artist...',
                    hintStyle: TextStyle(
                      color: CyberpunkTheme.tyrianPurple.withValues(alpha: 0.8),
                      fontSize: 15,
                    ),
                    prefixIcon: GestureDetector(
                      onTap: () => widget.onSearch(widget.controller.text),
                      child: const Icon(
                        Icons.search_sharp,
                        color: CyberpunkTheme.deepCerise,
                        size: 25,
                      ),
                    ),
                    filled: true,
                    fillColor: CyberpunkTheme.darkCold.withValues(
                      alpha: 0.1,
                    ), // const Color.fromARGB(255, 44, 28, 46),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: CyberpunkTheme.brightTurquoise.withValues(
                          alpha: 0.8,
                        ),
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: CyberpunkTheme.shimmerPink.withValues(
                          alpha: 0.8,
                        ),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
