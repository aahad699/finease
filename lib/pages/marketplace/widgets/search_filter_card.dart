import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

class SearchAndFilterCard extends StatelessWidget {
  const SearchAndFilterCard({
    required this.queryController,
    required this.categories,
    required this.selectedCategory,
    required this.selectedTags,
    required this.suggestedTags,
    required this.onCategorySelected,
    required this.onTagToggle,
    required this.onQueryChanged,
    required this.onClearFilters,
    super.key,
  });

  final TextEditingController queryController;
  final List<String> categories;
  final String selectedCategory;
  final Set<String> selectedTags;
  final List<String> suggestedTags;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onTagToggle;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final visibleTags = [...suggestedTags]
      ..sort((a, b) {
        final aSelected = selectedTags.contains(a);
        final bSelected = selectedTags.contains(b);
        if (aSelected == bSelected) return a.compareTo(b);
        return aSelected ? -1 : 1;
      });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: queryController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: queryController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        queryController.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              hintText:
                  'Search loans, insurance, jobs, rates, tags, or benefits',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(
            title: 'Categories',
            actionLabel: 'Reset',
            onAction: onClearFilters,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final value = categories[index];
                final selected = value == selectedCategory;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  child: ChoiceChip(
                    label: Text(value),
                    selected: selected,
                    onSelected: (_) => onCategorySelected(value),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                    labelStyle: GoogleFonts.inter(
                      color: selected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected ? AppTheme.primary : AppTheme.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel(title: 'Smart tags'),
          const SizedBox(height: 10),
          if (visibleTags.isEmpty)
            Text(
              'Tags will appear as partners add richer product details.',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleTags.take(12).map((tag) {
                final selected = selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (_) => onTagToggle(tag),
                  backgroundColor: const Color(0xFFF8FAFC),
                  selectedColor: const Color(0xFFDCFCE7),
                  labelStyle: GoogleFonts.inter(
                    color: selected ? AppTheme.success : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected ? const Color(0xFF86EFAC) : AppTheme.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
