import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_config_gate.dart';

class WelfareProgramsPage extends StatefulWidget {
  const WelfareProgramsPage({super.key});

  @override
  State<WelfareProgramsPage> createState() => _WelfareProgramsPageState();
}

class _WelfareProgramsPageState extends State<WelfareProgramsPage> {
  String _searchQuery = '';
  String _selectedCategory = 'All Programs';

  final List<Map<String, dynamic>> _allPrograms = [
    {
      'category': 'Cash Support',
      'title': 'Benazir Income Support Programme',
      'description':
          'National cash support for low-income households with registration, eligibility checks, and payment support channels.',
      'orgName': 'Government of Pakistan',
      'statusLabel': 'Eligibility',
      'statusValue': 'Low-income families',
      'link': 'https://bisp.gov.pk/',
      'icon': Icons.payments_outlined,
      'badgeColor': const Color(0xFFDCE9FF),
      'badgeTextColor': AppTheme.primary,
    },
    {
      'category': 'Education',
      'title': 'Ehsaas Undergraduate Scholarship',
      'description':
          'Need-based higher education scholarship for deserving students enrolled in partner universities across Pakistan.',
      'orgName': 'Higher Education Commission',
      'statusLabel': 'Support',
      'statusValue': 'Tuition and stipend',
      'link':
          'https://www.hec.gov.pk/english/scholarshipsgrants/EHSAAS/Pages/default.aspx',
      'icon': Icons.school_outlined,
      'badgeColor': const Color(0xFFDBFCE7),
      'badgeTextColor': const Color(0xFF166534),
    },
    {
      'category': 'Healthcare',
      'title': 'Sehat Sahulat Program',
      'description':
          'Health coverage program for eligible families with empaneled hospitals and treatment support.',
      'orgName': 'State Life / Government of Pakistan',
      'statusLabel': 'Coverage',
      'statusValue': 'Hospital treatment support',
      'link': 'https://www.pmhealthprogram.gov.pk/',
      'icon': Icons.local_hospital_outlined,
      'badgeColor': const Color(0xFFFFEDD5),
      'badgeTextColor': const Color(0xFF9A3412),
    },
    {
      'category': 'Loans',
      'title': 'Akhuwat Foundation Loans',
      'description':
          'Interest-free microfinance and livelihood support for small business, education, and household needs.',
      'orgName': 'Akhuwat Foundation',
      'statusLabel': 'Type',
      'statusValue': 'Interest-free support',
      'link': 'https://akhuwat.org.pk/',
      'icon': Icons.account_balance_outlined,
      'badgeColor': const Color(0xFFE0F2FE),
      'badgeTextColor': const Color(0xFF075985),
    },
    {
      'category': 'Relief',
      'title': 'Pakistan Bait-ul-Mal',
      'description':
          'Support for widows, orphans, persons with disabilities, and families facing hardship through multiple relief schemes.',
      'orgName': 'Pakistan Bait-ul-Mal',
      'statusLabel': 'Focus',
      'statusValue': 'Relief and rehabilitation',
      'link': 'https://www.pbm.gov.pk/',
      'icon': Icons.volunteer_activism_outlined,
      'badgeColor': const Color(0xFFFCE7F3),
      'badgeTextColor': const Color(0xFF9D174D),
    },
    {
      'category': 'Housing',
      'title': 'Punjab Housing and Town Planning Agency',
      'description':
          'Housing support information, affordable schemes, and planning initiatives for eligible residents.',
      'orgName': 'PHATA Punjab',
      'statusLabel': 'Region',
      'statusValue': 'Punjab',
      'link': 'https://phata.punjab.gov.pk/',
      'icon': Icons.home_work_outlined,
      'badgeColor': const Color(0xFFEDE9FE),
      'badgeTextColor': const Color(0xFF5B21B6),
    },
  ];

  List<Map<String, dynamic>> get _filteredPrograms {
    return _allPrograms.where((program) {
      final query = _searchQuery.toLowerCase();
      final matchesQuery =
          program['title'].toString().toLowerCase().contains(query) ||
          program['orgName'].toString().toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'All Programs' ||
          program['category'] == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppFeatureGate(
      enabled: (config) => config.welfareEnabled,
      blockedTitle: 'Welfare programs are paused',
      blockedMessage:
          'The welfare directory is temporarily paused by FinEase admin.',
      blockedIcon: Icons.volunteer_activism_outlined,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: Colors.black,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Welfare Programs',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verified support programs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Discover real welfare, scholarship, health, and support programs in Pakistan and open their official application websites directly.',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: 'Search programs or organizations',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip('All Programs'),
                    _buildChip('Cash Support'),
                    _buildChip('Education'),
                    _buildChip('Healthcare'),
                    _buildChip('Loans'),
                    _buildChip('Relief'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ..._filteredPrograms.map(
                (program) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProgramCard(
                    program: program,
                    onApply: () => _launchProgram(program['link'] as String),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Impact snapshot',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Use FinEase to compare real support pathways before you apply.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _ImpactStat(value: '6', label: 'VERIFIED PROGRAMS'),
                        _ImpactStat(value: '4', label: 'SUPPORT TYPES'),
                        _ImpactStat(value: '100%', label: 'OFFICIAL LINKS'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchProgram(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open program website.')),
      );
    }
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, required this.onApply});

  final Map<String, dynamic> program;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  program['icon'] as IconData,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: program['badgeColor'] as Color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  program['category'] as String,
                  style: GoogleFonts.inter(
                    color: program['badgeTextColor'] as Color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            program['title'] as String,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            program['description'] as String,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            program['orgName'] as String,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program['statusLabel'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    program['statusValue'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: onApply,
                child: const Text('Apply Now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  const _ImpactStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
