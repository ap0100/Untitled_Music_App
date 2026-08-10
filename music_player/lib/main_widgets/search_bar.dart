import 'package:flutter/material.dart';

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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(0.0, 0.2),
          end: const Alignment(0.0, 1.6),
          colors: const [
            Color.fromARGB(255, 9, 12, 12),
            Color.fromARGB(255, 34, 28, 46),
          ],
        ),
      ),
      padding: const EdgeInsets.only(left: 8, right: 8, top: 25, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          const Text(
            'Music App',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 153, 233, 222),
            ),
          ),
          const Text(
            'no ads, no premium, just music --- developed by ap0100',
            style: TextStyle(
              fontSize: 13,
              color: Color.fromARGB(255, 232, 173, 240),
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 40,
            child: TextField(
              focusNode: _focusNode,
              controller: widget.controller,
              cursorColor: const Color.fromARGB(255, 40, 163, 163),
              onSubmitted: widget.onSubmitted,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Color.fromARGB(255, 173, 240, 215),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: 'Search song, artist...',
                hintStyle: const TextStyle(
                  color: Color.fromARGB(255, 40, 94, 90),
                  fontSize: 15,
                ),
                prefixIcon: GestureDetector(
                  onTap: () => widget.onSearch(widget.controller.text),
                  child: const Icon(
                    Icons.search_sharp,
                    color: Color.fromARGB(255, 219, 86, 190),
                    size: 25,
                  ),
                ),
                filled: true,
                fillColor: const Color.fromARGB(255, 44, 28, 46),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Color.fromARGB(255, 40, 163, 163),
                    width: 1.2,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Color.fromARGB(255, 216, 71, 221),
                    width: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
