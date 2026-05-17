// lib/pages/welfare/welfare_program_detail_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/welfare_program.dart';
import '../../services/url_launcher_service.dart';
import '../../theme/app_theme.dart';
import 'welfare_provider.dart';

class WelfareProgramDetailPage extends StatelessWidget {
  const WelfareProgramDetailPage({super.key, required this.program});

  final WelfareProgram program;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WelfareProvider>();
    final bookmarked = provider.isBookmarked(program.id);
    final appStatus = provider.applicationStatus(program.id);

    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      body: CustomScrollView(
        slivers: [
          _DetailAppBar(program: program, bookmarked: bookmarked, provider: provider),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _HeaderSection(program: program),
                const SizedBox(height: 20),
                _MetadataRow(program: program),
                const SizedBox(height: 24),
                if (appStatus != null) _StatusBanner(status: appStatus),
                if (appStatus != null) const SizedBox(height: 20),
                _SectionCard(
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.success,
                  title: 'Eligibility Criteria',
                  child: _BulletList(items: program.eligibilityCriteria, color: AppTheme.success),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.folder_outlined,
                  color: AppTheme.warning,
                  title: 'Required Documents',
                  child: _BulletList(items: program.requiredDocuments, color: AppTheme.warning),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.list_alt_rounded,
                  color: AppTheme.primary,
                  title: 'Application Process',
                  child: _StepList(steps: program.applicationSteps),
                ),
                const SizedBox(height: 16),
                _ContactCard(program: program),
                const SizedBox(height: 24),
                _TrackingSection(program: program, currentStatus: appStatus),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomCTA(program: program),
    );
  }
}

// ─── App Bar ───────────────────────────────────────────────────────────────────

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({required this.program, required this.bookmarked, required this.provider});
  final WelfareProgram program;
  final bool bookmarked;
  final WelfareProvider provider;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppTheme.primary,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              key: ValueKey(bookmarked),
              color: Colors.white,
            ),
          ),
          onPressed: () => provider.toggleBookmark(program.id),
          tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark program',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: AppTheme.cardGradient),
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: program.category.badgeColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      program.category.displayName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (program.isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header Section ────────────────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.program});
  final WelfareProgram program;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          program.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryFor(context),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.corporate_fare_rounded, size: 14, color: AppTheme.textSecondaryFor(context)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                program.organization,
                style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(context), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (program.regionRestriction != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondaryFor(context)),
              const SizedBox(width: 5),
              Text(
                program.regionRestriction!,
                style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(context), fontSize: 13),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          program.description,
          style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(context), height: 1.6, fontSize: 15),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: program.tags
              .map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#$tag',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─── Metadata Row ──────────────────────────────────────────────────────────────

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.program});
  final WelfareProgram program;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          _MetaTile(
            label: program.supportValueLabel,
            value: program.estimatedSupportValue,
            icon: Icons.payments_outlined,
            iconColor: AppTheme.success,
          ),
          _divider(context),
          _DifficultyTile(level: program.difficulty),
          _divider(context),
          _MetaTile(
            label: 'Verification',
            value: program.isVerified ? 'Official' : 'Unverified',
            icon: program.isVerified ? Icons.verified_outlined : Icons.help_outline_rounded,
            iconColor: program.isVerified ? AppTheme.success : AppTheme.warning,
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: AppTheme.borderFor(context),
      );
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.label, required this.value, required this.icon, required this.iconColor});
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppTheme.textPrimaryFor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondaryFor(context)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({required this.level});
  final DifficultyLevel level;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.speed_rounded, size: 18, color: level.color),
          const SizedBox(height: 5),
          Text(
            level.label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: level.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Complexity',
            style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondaryFor(context)),
          ),
        ],
      ),
    );
  }
}

// ─── Status Banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            'Application Status: $label',
            style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  (String, IconData, Color) _statusStyle(ApplicationStatus s) {
    return switch (s) {
      ApplicationStatus.saved => ('Saved', Icons.bookmark_rounded, AppTheme.primary),
      ApplicationStatus.applied => ('Applied', Icons.send_rounded, AppTheme.warning),
      ApplicationStatus.inReview => ('In Review', Icons.hourglass_top_rounded, AppTheme.warning),
      ApplicationStatus.approved => ('Approved', Icons.check_circle_rounded, AppTheme.success),
      ApplicationStatus.rejected => ('Not Approved', Icons.cancel_rounded, AppTheme.error),
    };
  }
}

// ─── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.color, required this.title, required this.child});
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderFor(context)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Bullet List ───────────────────────────────────────────────────────────────

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.color});
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(context), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ─── Step List ─────────────────────────────────────────────────────────────────

class _StepList extends StatelessWidget {
  const _StepList({required this.steps});
  final List<ApplicationStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps.asMap().entries.map((entry) {
        final isLast = entry.key == steps.length - 1;
        final step = entry.value;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${step.stepNumber}',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 44,
                    color: AppTheme.borderFor(context),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryFor(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Contact Card ──────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.program});
  final WelfareProgram program;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.contact_support_outlined, color: AppTheme.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Contact & Helpline',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderFor(context)),
          if (program.helplineNumber.isNotEmpty)
            _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Helpline',
              value: program.helplineNumber,
              onTap: () => UrlLauncherService.instance.launchPhoneDialer(context, program.helplineNumber),
            ),
          if (program.helplineEmail.isNotEmpty)
            _ContactRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: program.helplineEmail,
              onTap: () => UrlLauncherService.instance.launchEmail(context, program.helplineEmail),
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryFor(context))),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondaryFor(context), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Application Tracking Section ─────────────────────────────────────────────

class _TrackingSection extends StatelessWidget {
  const _TrackingSection({required this.program, required this.currentStatus});
  final WelfareProgram program;
  final ApplicationStatus? currentStatus;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WelfareProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Track Your Application',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryFor(context),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ApplicationStatus.saved,
            ApplicationStatus.applied,
            ApplicationStatus.inReview,
            ApplicationStatus.approved,
          ]
              .map((status) => _StatusChip(
                    status: status,
                    isSelected: currentStatus == status,
                    onTap: () {
                      if (currentStatus == status) {
                        // Allow deselect — not implemented to keep it simple
                        provider.setApplicationStatus(program.id, status);
                      } else {
                        provider.setApplicationStatus(program.id, status);
                      }
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isSelected, required this.onTap});
  final ApplicationStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ApplicationStatus.saved => 'Saved',
      ApplicationStatus.applied => 'Applied',
      ApplicationStatus.inReview => 'In Review',
      ApplicationStatus.approved => 'Approved',
      ApplicationStatus.rejected => 'Rejected',
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceFor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.borderFor(context),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondaryFor(context),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Bottom CTA ────────────────────────────────────────────────────────────────

class _BottomCTA extends StatelessWidget {
  const _BottomCTA({required this.program});
  final WelfareProgram program;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceFor(context),
          border: Border(top: BorderSide(color: AppTheme.borderFor(context))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
              Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await UrlLauncherService.instance.launchExternalUrl(context, program.officialUrl);
                },
                icon: Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Apply on Official Website'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Consumer<WelfareProvider>(
              builder: (_, provider, _) {
                final bookmarked = provider.isBookmarked(program.id);
                return IconButton.outlined(
                  onPressed: () => provider.toggleBookmark(program.id),
                  icon: Icon(
                    bookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                    color: AppTheme.primary,
                  ),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(13),
                    side: BorderSide(color: AppTheme.borderFor(context)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
