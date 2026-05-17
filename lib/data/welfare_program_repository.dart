// lib/data/welfare_program_repository.dart
//
// Single source of truth for all welfare program data.
// Priority: Firestore `welfare_programs` collection → bundled local data.
// To remotely manage programs, add/update documents in Firestore —
// no app release needed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/welfare_program.dart';

class WelfareProgramRepository {
  WelfareProgramRepository._();
  static final WelfareProgramRepository instance = WelfareProgramRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches programs: tries Firestore first, falls back to local bundle.
  Future<List<WelfareProgram>> fetchPrograms() async {
    try {
      final snap = await _db
          .collection('welfare_programs')
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache));

      if (snap.docs.isNotEmpty) {
        debugPrint(
          '[WelfareProgramRepository] Loaded ${snap.docs.length} programs from Firestore.',
        );
        return snap.docs.map((d) => WelfareProgram.fromFirestore(d)).toList();
      }
    } catch (e) {
      debugPrint(
        '[WelfareProgramRepository] Firestore fetch failed, using local data: $e',
      );
    }

    // Fallback: bundled local dataset
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint(
      '[WelfareProgramRepository] Using ${_programs.length} local programs.',
    );
    return _programs;
  }

  /// Seeds Firestore with local data (admin utility — call once from admin dashboard).
  Future<void> seedFirestore() async {
    final batch = _db.batch();
    for (final program in _programs) {
      final ref = _db.collection('welfare_programs').doc(program.id);
      batch.set(ref, program.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
    debugPrint(
      '[WelfareProgramRepository] Seeded ${_programs.length} programs to Firestore.',
    );
  }

  static const List<WelfareProgram> _programs = [
    // ── CASH SUPPORT ─────────────────────────────────────────────────────────
    WelfareProgram(
      id: 'bisp_001',
      title: 'Benazir Income Support Programme',
      organization: 'Government of Pakistan',
      description:
          'National cash transfer programme providing quarterly financial assistance to low-income households. Registration is done via BISP tehsil offices or the 8171 helpline. Eligible families receive a PKR 8,750 quarterly payment directly to a Benazir Debit Card.',
      category: WelfareCategory.relief,
      tags: ['low-income', 'cash', 'quarterly', 'government', 'national'],
      officialUrl: 'https://bisp.gov.pk/',
      eligibilityCriteria: [
        'Family income below PKR 45,000 per month',
        'Must be registered in NSER (National Socio-Economic Registry)',
        'Pakistani citizen with valid CNIC',
        'Not a government employee',
        'Not a taxpayer (income tax filer)',
      ],
      requiredDocuments: [
        'Original CNIC of female head of household',
        'B-Form or CNIC of all family members',
        'Proof of residence (utility bill or affidavit)',
        'Phone number registered against CNIC',
      ],
      applicationSteps: [
        ApplicationStep(
          stepNumber: 1,
          title: 'Check Eligibility via SMS',
          description:
              'Send your CNIC number to 8171. You will receive an SMS confirming whether you are eligible.',
        ),
        ApplicationStep(
          stepNumber: 2,
          title: 'Visit Nearest BISP Tehsil Office',
          description:
              'Bring your CNIC and required documents to your nearest BISP office for biometric verification.',
        ),
        ApplicationStep(
          stepNumber: 3,
          title: 'Complete NSER Survey',
          description:
              'A BISP surveyor will conduct a household survey to verify your socio-economic status.',
        ),
        ApplicationStep(
          stepNumber: 4,
          title: 'Receive Benazir Debit Card',
          description:
              'Once approved, you will receive a payment card from Habib Bank Limited for quarterly disbursements.',
        ),
      ],
      difficulty: DifficultyLevel.easy,
      estimatedSupportValue: 'PKR 8,750/quarter',
      supportValueLabel: 'Quarterly cash transfer',
      helplineNumber: '8171',
      helplineEmail: 'info@bisp.gov.pk',
      forLowIncome: true,
      forEmergency: true,
    ),

    // ── EDUCATION ─────────────────────────────────────────────────────────────
    WelfareProgram(
      id: 'hec_ehsaas_001',
      title: 'Ehsaas Undergraduate Scholarship',
      organization: 'Higher Education Commission (HEC)',
      description:
          'Need-based financial scholarship for deserving students enrolled in HEC-recognised public and private universities. Covers full tuition and a monthly living stipend, enabling talented students from low-income backgrounds to complete their undergraduate degrees.',
      category: WelfareCategory.education,
      tags: [
        'student',
        'scholarship',
        'university',
        'tuition',
        'stipend',
        'low-income',
        'HEC',
      ],
      officialUrl:
          'https://www.hec.gov.pk/english/scholarshipsgrants/EHSAAS/Pages/default.aspx',
      eligibilityCriteria: [
        'Pakistani national currently enrolled in an HEC-recognised university',
        'Family income below PKR 45,000 per month',
        'Minimum 60% marks in Matric and Intermediate',
        'Not receiving any other government scholarship',
        'Must be a first-generation college student (preferred)',
      ],
      requiredDocuments: [
        'Student CNIC / B-Form',
        'Parent/Guardian CNIC',
        'University admission letter',
        'Matric and Intermediate certificates with DMC',
        'Proof of family income (salary slip or affidavit)',
        '2 recent passport-size photographs',
      ],
      applicationSteps: [
        ApplicationStep(
          stepNumber: 1,
          title: 'Register on HEC Portal',
          description:
              'Create an account on the HEC Scholarship portal (scholarship.hec.gov.pk) and complete your profile.',
        ),
        ApplicationStep(
          stepNumber: 2,
          title: 'Fill Online Application Form',
          description:
              'Select "Ehsaas Undergraduate Scholarship" and fill in your academic, financial, and personal details.',
        ),
        ApplicationStep(
          stepNumber: 3,
          title: 'Upload Required Documents',
          description:
              'Scan and upload all supporting documents in PDF format. Ensure each file is under 2MB.',
        ),
        ApplicationStep(
          stepNumber: 4,
          title: 'University Verification',
          description:
              'Your university scholarship office will verify your enrollment and academic standing.',
        ),
        ApplicationStep(
          stepNumber: 5,
          title: 'Await HEC Decision',
          description:
              'HEC will review your application and notify you via email and SMS within 45 working days.',
        ),
      ],
      difficulty: DifficultyLevel.moderate,
      estimatedSupportValue: 'Up to PKR 60,000/year',
      supportValueLabel: 'Tuition + monthly stipend',
      helplineNumber: '051-90402000',
      helplineEmail: 'ugscholarship@hec.gov.pk',
      forStudents: true,
      forLowIncome: true,
    ),

    WelfareProgram(
      id: 'akhuwat_edu_001',
      title: 'Akhuwat Education Services',
      organization: 'Akhuwat Foundation',
      description:
          'Interest-free education loans for students who cannot afford tuition fees. Disbursed through a mosque/church-based community model with flexible repayment. Also provides fee-waiver scholarships at Akhuwat University.',
      category: WelfareCategory.education,
      tags: [
        'student',
        'interest-free',
        'loan',
        'education',
        'university',
        'microfinance',
      ],
      officialUrl: 'https://akhuwat.org.pk/programs/education/',
      eligibilityCriteria: [
        'Pakistani national enrolled in a recognised institution',
        'Family income below PKR 60,000 per month',
        'Demonstrated academic merit (min 50% marks)',
        'Willingness to repay after graduation',
      ],
      requiredDocuments: [
        'CNIC / B-Form of student and parent',
        'University/College enrollment letter',
        'Latest mark sheets',
        'Proof of household income',
        'Two guarantors with CNICs',
      ],
      applicationSteps: [
        ApplicationStep(
          stepNumber: 1,
          title: 'Visit Nearest Akhuwat Branch',
          description:
              'Find your nearest Akhuwat branch at akhuwat.org.pk and submit an initial inquiry form.',
        ),
        ApplicationStep(
          stepNumber: 2,
          title: 'Complete Application',
          description:
              'Fill the loan/scholarship application with your academic and financial details.',
        ),
        ApplicationStep(
          stepNumber: 3,
          title: 'Community Verification',
          description:
              'An Akhuwat representative will conduct a home visit for needs assessment.',
        ),
        ApplicationStep(
          stepNumber: 4,
          title: 'Disbursement',
          description:
              'Approved funds are disbursed directly to the institution\'s fee account or via cheque.',
        ),
      ],
      difficulty: DifficultyLevel.easy,
      estimatedSupportValue: 'Up to PKR 300,000',
      supportValueLabel: 'Interest-free education loan',
      helplineNumber: '042-35761999',
      helplineEmail: 'info@akhuwat.org.pk',
      forStudents: true,
      forLowIncome: true,
    ),

    // ── HEALTHCARE ────────────────────────────────────────────────────────────
    WelfareProgram(
      id: 'sehat_sahulat_001',
      title: 'Sehat Sahulat Program',
      organization: 'State Life / PM Health Initiative',
      description:
          'Health insurance coverage for eligible families providing cashless treatment at empaneled public and private hospitals. Covers secondary and tertiary care procedures with an annual family ceiling of PKR 1,000,000.',
      category: WelfareCategory.healthcare,
      tags: [
        'healthcare',
        'insurance',
        'hospital',
        'treatment',
        'low-income',
        'family',
      ],
      officialUrl: 'https://www.pmhealthprogram.gov.pk/',
      eligibilityCriteria: [
        'Must be registered in NSER database',
        'Active BISP beneficiary or eligible non-BISP family',
        'All family members listed on one CNIC family',
        'Applicable in enrolled districts/provinces',
      ],
      requiredDocuments: [
        'CNIC of head of household',
        'Family member B-Forms',
        'Sehat Sahulat Card (issued automatically to eligible families)',
      ],
      applicationSteps: [
        ApplicationStep(
          stepNumber: 1,
          title: 'Verify Eligibility',
          description:
              'Check eligibility by visiting pmhealthprogram.gov.pk or calling the helpline with your CNIC.',
        ),
        ApplicationStep(
          stepNumber: 2,
          title: 'Receive Sehat Card',
          description:
              'Eligible families receive the Sehat Sahulat Card via post or from their local BISP office.',
        ),
        ApplicationStep(
          stepNumber: 3,
          title: 'Visit Empaneled Hospital',
          description:
              'Go to any empaneled hospital with your Sehat Card and CNIC for cashless treatment.',
        ),
        ApplicationStep(
          stepNumber: 4,
          title: 'Claim Processing',
          description:
              'The hospital processes the claim directly with State Life. No out-of-pocket payment is required for covered procedures.',
        ),
      ],
      difficulty: DifficultyLevel.easy,
      estimatedSupportValue: 'Up to PKR 1,000,000/year',
      supportValueLabel: 'Cashless hospital coverage',
      helplineNumber: '0311-1117569',
      helplineEmail: 'support@pmhealthprogram.gov.pk',
      forLowIncome: true,
      forHealthcare: true,
      forDisabled: true,
    ),

    // ── BUSINESS & LOANS ──────────────────────────────────────────────────────
    WelfareProgram(
      id: 'akhuwat_micro_001',
      title: 'Akhuwat Interest-Free Microloans',
      organization: 'Akhuwat Foundation',
      description:
          'Interest-free (Qarz-e-Hasna) microfinance for small businesses, household needs, marriage support, and livelihood restoration. Disbursed in a community/mosque setting with a social guarantor model replacing collateral.',
      category: WelfareCategory.business,
      tags: [
        'loan',
        'interest-free',
        'microloan',
        'SME',
        'business',
        'livelihood',
        'microfinance',
      ],
      officialUrl: 'https://akhuwat.org.pk/',
      eligibilityCriteria: [
        'Pakistani citizen with valid CNIC',
        'Not already an active Akhuwat borrower',
        'Has a viable business plan or declared need',
        'Must provide two community guarantors',
        'Family income below PKR 50,000/month',
      ],
      requiredDocuments: [
        'CNIC of applicant and spouse',
        'Utility bill for address verification',
        'CNICs of two guarantors',
        'Recent photographs (2 passport size)',
        'Business plan or description of intended use',
      ],
      applicationSteps: [
        ApplicationStep(
          stepNumber: 1,
          title: 'Attend Community Orientation',
          description:
              'Attend a group orientation session at your nearest Akhuwat branch to understand the programme.',
        ),
        ApplicationStep(
          stepNumber: 2,
          title: 'Submit Application',
          description:
              'Complete the loan application form with your financial and business details.',
        ),
        ApplicationStep(
          stepNumber: 3,
          title: 'Home/Business Appraisal',
          description:
              'An Akhuwat loan officer will visit your home or business for a needs assessment.',
        ),
        ApplicationStep(
          stepNumber: 4,
          title: 'Loan Committee Approval',
          description:
              'Your case is reviewed by the branch loan committee. Approval is communicated within 5 working days.',
        ),
        ApplicationStep(
          stepNumber: 5,
          title: 'Disbursement Ceremony',
          description:
              'Loan is disbursed at a group ceremony in a mosque/community hall with all applicants present.',
        ),
      ],
      difficulty: DifficultyLevel.easy,
      estimatedSupportValue: 'PKR 10,000 – PKR 500,000',
      supportValueLabel: 'Interest-free business microloan',
      helplineNumber: '042-35761999',
      helplineEmail: 'info@akhuwat.org.pk',
      forSME: true,
      forLowIncome: true,
    ),

    WelfareProgram(
      id: 'smeda_001',
      title: 'PM\'s Kamyab Jawan Youth Entrepreneurship',
      organization: 'SMEDA / National Bank of Pakistan',
      description:
          'Subsidised business loans at 3–5% markup for young Pakistani entrepreneurs aged 21–45. Covers startups, existing businesses, and agricultural ventures with loan sizes from PKR 100,000 to PKR 25 million.',
      category: WelfareCategory.business,
      tags: [
        'youth',
        'entrepreneur',
        'startup',
        'loan',
        'SME',
        'business',
        'government',
      ],
      officialUrl: 'https://kamyabjawan.gov.pk/',
      eligibilityCriteria: [
        'Pakistani national aged 21–45 years',
        'Valid CNIC',
        'Viable business plan (startup or existing)',
        'No loan default history with any bank',
        'Educational qualification: minimum matriculation',
      ],
      requiredDocuments: [
        'CNIC copy',
        'Business plan document',
        '6 months bank statement',
        'Educational certificates',
        'Property documents (for secured loans above PKR 1M)',
        '2 passport photographs',
      ],
      applicationSteps: [
        ApplicationStep(
          stepNumber: 1,
          title: 'Apply Online',
          description:
              'Register and apply at kamyabjawan.gov.pk. Select your loan tier and fill the business plan template.',
        ),
        ApplicationStep(
          stepNumber: 2,
          title: 'Bank Processing',
          description:
              'Your designated bank (NBP, HBL, UBL, etc.) contacts you for document verification.',
        ),
        ApplicationStep(
          stepNumber: 3,
          title: 'Business Assessment',
          description:
              'Bank officers conduct a physical visit to assess the viability of your business plan.',
        ),
        ApplicationStep(
          stepNumber: 4,
          title: 'Credit Committee Approval',
          description:
              'The bank\'s credit committee reviews and approves or rejects the application.',
        ),
        ApplicationStep(
          stepNumber: 5,
          title: 'Loan Disbursement',
          description:
              'Approved amounts are disbursed to your business account. A 6-month grace period applies.',
        ),
      ],
      difficulty: DifficultyLevel.complex,
      estimatedSupportValue: 'PKR 100K – PKR 25M',
      supportValueLabel: 'Subsidised startup/business loan',
      helplineNumber: '051-9204760',
      helplineEmail: 'info@smeda.org.pk',
      forSME: true,
    ),

    // ── HOUSING ───────────────────────────────────────────────────────────────
    WelfareProgram(
      id: 'phata_001',
      title: 'Punjab Apna Ghar Housing Scheme',
      organization: 'PHATA / Government of Punjab',
      description:
          'Affordable subsidised housing scheme for low and middle-income residents of Punjab. Provides plots and constructed units on easy 10–20 year instalments at government-controlled rates.',
      category: WelfareCategory.housing,
      tags: [
        'housing',
        'plot',
        'affordable',
        'Punjab',
        'instalment',
        'low-income',
      ],
      officialUrl: 'https://phata.punjab.gov.pk/',
      eligibilityCriteria: [
        'Domicile of Punjab',
        'Income below PKR 70,000/month for subsidised tier',
        'Must not own a residential property in any city of Pakistan',
        'Age 25–60 years at time of application',
      ],
      requiredDocuments: [
        'Punjab domicile certificate',
        'CNIC',
        'Proof of income (salary slip / income certificate)',
        'Affidavit of no existing property ownership',
        'Bank account details for instalment setup',
      ],
      applicationSteps: [
        ApplicationStep(
          stepNumber: 1,
          title: 'Check Active Schemes',
          description:
              'Visit phata.punjab.gov.pk or PHATA office to check currently open housing schemes and locations.',
        ),
        ApplicationStep(
          stepNumber: 2,
          title: 'Submit Online Application',
          description:
              'Complete the online registration form with personal, financial, and preferred location details.',
        ),
        ApplicationStep(
          stepNumber: 3,
          title: 'Ballot / Selection',
          description:
              'If demand exceeds supply, a computerised ballot is held. Successful applicants are notified.',
        ),
        ApplicationStep(
          stepNumber: 4,
          title: 'Pay Booking Amount',
          description:
              'Pay the initial booking amount via designated bank branches within the specified deadline.',
        ),
        ApplicationStep(
          stepNumber: 5,
          title: 'Complete Documentation',
          description:
              'Submit all physical documents to the PHATA office and sign the housing agreement.',
        ),
      ],
      difficulty: DifficultyLevel.moderate,
      estimatedSupportValue: 'Subsidised market rates',
      supportValueLabel: 'Affordable housing on instalments',
      helplineNumber: '042-99213281',
      helplineEmail: 'info@phata.gop.pk',
      regionRestriction: 'Punjab',
      forLowIncome: true,
    ),

    // ── RELIEF ────────────────────────────────────────────────────────────────
    WelfareProgram(
      id: 'pbm_001',
      title: 'Pakistan Bait-ul-Mal Individual Financial Assistance',
      organization: 'Pakistan Bait-ul-Mal',
      description:
          'Direct financial relief for widows, orphans, persons with disabilities, and families facing extreme hardship. Covers medical treatment costs, educational support, and rehabilitation grants through multiple targeted schemes.',
      category: WelfareCategory.relief,
      tags: [
        'widow',
        'orphan',
        'disabled',
        'relief',
        'emergency',
        'rehabilitation',
        'medical',
      ],
      officialUrl: 'https://www.pbm.gov.pk/',
      eligibilityCriteria: [
        'Pakistani citizen in genuine financial need',
        'Widows, orphans, or persons with disabilities given priority',
        'No government pension or other income above subsistence level',
        'Resident of Pakistan',
      ],
      requiredDocuments: [
        'CNIC / B-Form',
        'Proof of financial need (income statement / affidavit)',
        'Death certificate of spouse (for widows)',
        'Disability certificate from PMRC (for disabled persons)',
        'Medical certificates if applying for medical assistance',
        '2 passport photographs',
      ],
      applicationSteps: [
        ApplicationStep(
          stepNumber: 1,
          title: 'Download Application Form',
          description:
              'Download the relevant assistance form from pbm.gov.pk or collect from the nearest PBM district office.',
        ),
        ApplicationStep(
          stepNumber: 2,
          title: 'Submit to District Office',
          description:
              'Submit completed form with all attached documents at the PBM district/tehsil office.',
        ),
        ApplicationStep(
          stepNumber: 3,
          title: 'Social Inquiry',
          description:
              'A PBM social welfare officer conducts an inquiry to verify your circumstances and needs.',
        ),
        ApplicationStep(
          stepNumber: 4,
          title: 'Review and Approval',
          description:
              'The District Committee reviews the case and recommends approval to the Head Office.',
        ),
        ApplicationStep(
          stepNumber: 5,
          title: 'Disbursement',
          description:
              'Approved funds are released via crossed cheque or bank transfer to the beneficiary.',
        ),
      ],
      difficulty: DifficultyLevel.moderate,
      estimatedSupportValue: 'Varies by scheme',
      supportValueLabel: 'One-time or recurring grant',
      helplineNumber: '051-9245497',
      helplineEmail: 'info@pbm.gov.pk',
      forLowIncome: true,
      forDisabled: true,
      forWidows: true,
      forEmergency: true,
    ),

    // ── EMERGENCY ─────────────────────────────────────────────────────────────
    WelfareProgram(
      id: 'ndma_001',
      title: 'NDMA Disaster Relief Assistance',
      organization: 'National Disaster Management Authority',
      description:
          'Emergency cash and in-kind assistance for families affected by floods, earthquakes, and other natural disasters. Coordination with provincial PDMAs ensures timely shelter, food, and reconstruction support.',
      category: WelfareCategory.emergency,
      tags: [
        'emergency',
        'disaster',
        'flood',
        'earthquake',
        'relief',
        'cash',
        'government',
      ],
      officialUrl: 'https://ndma.gov.pk/',
      eligibilityCriteria: [
        'Directly affected by a declared national or provincial disaster',
        'Must be registered by NDMA/PDMA survey teams on the ground',
        'Loss of primary residence or livelihood',
      ],
      requiredDocuments: [
        'CNIC',
        'Disaster registration slip from NDMA/PDMA survey team',
        'Proof of property loss (photographs, FIR if applicable)',
      ],
      applicationSteps: [
        ApplicationStep(
          stepNumber: 1,
          title: 'Register with Relief Camp',
          description:
              'Visit the nearest NDMA/PDMA relief camp and register your family for assistance.',
        ),
        ApplicationStep(
          stepNumber: 2,
          title: 'Needs Assessment',
          description:
              'NDMA/PDMA teams conduct on-site assessment of damage and immediate needs.',
        ),
        ApplicationStep(
          stepNumber: 3,
          title: 'Receive Immediate Relief',
          description:
              'Food rations, tents, and household items are distributed as first-response relief.',
        ),
        ApplicationStep(
          stepNumber: 4,
          title: 'Cash Transfer via Watan Card',
          description:
              'Eligible families receive a Watan Card loaded with disaster relief funds from HBL/Mobilink.',
        ),
      ],
      difficulty: DifficultyLevel.easy,
      estimatedSupportValue: 'PKR 25,000 – PKR 200,000',
      supportValueLabel: 'One-time disaster relief grant',
      helplineNumber: '1700',
      helplineEmail: 'info@ndma.gov.pk',
      forEmergency: true,
      forLowIncome: true,
    ),
  ];
}
