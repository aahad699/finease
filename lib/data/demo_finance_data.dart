import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../models/budget_plan.dart';
import '../models/saving_goal.dart';
import '../models/transaction.dart';

class LessonCourse {
  const LessonCourse({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.coverImageUrl,
    required this.category,
    required this.difficulty,
    required this.durationMinutes,
    required this.outcome,
    required this.pathLabel,
    required this.rating,
    required this.xpReward,
    required this.skillTags,
    required this.lessons,
    required this.quiz,
    required this.externalUrl,
    required this.videoUrl,
    this.trackId = 'beginner',
    this.videoId,
    this.prerequisites = const [],
    this.localRelevance = '',
    this.capstone = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String coverImageUrl;
  final String category;
  final String difficulty;
  final int durationMinutes;
  final String outcome;
  final String pathLabel;
  final double rating;
  final int xpReward;
  final List<String> skillTags;
  final List<Lesson> lessons;
  final CourseQuiz quiz;
  final String externalUrl;
  final String videoUrl;
  final String trackId;
  final String? videoId;
  final List<String> prerequisites;
  final String localRelevance;
  final String capstone;
}

class LearningTrack {
  const LearningTrack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.iconName,
    required this.color,
    required this.goal,
  });

  final String id;
  final String title;
  final String subtitle;
  final String level;
  final String iconName;
  final Color color;
  final String goal;
}

class CourseQuiz {
  const CourseQuiz({
    required this.id,
    required this.title,
    required this.questions,
  });

  final String id;
  final String title;
  final List<QuizQuestion> questions;
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class DemoFinanceData {
  static const List<LearningTrack> learningTracks = [
    LearningTrack(
      id: 'beginner',
      title: 'Beginner',
      subtitle: 'Money basics, habits, and first financial wins',
      level: 'Start here',
      iconName: 'school',
      color: Color(0xFF2E3192),
      goal: 'Build confidence with budgeting, saving, and debt basics.',
    ),
    LearningTrack(
      id: 'intermediate',
      title: 'Intermediate',
      subtitle: 'Planning systems, investing, taxes, and protection',
      level: 'Level up',
      iconName: 'trending_up',
      color: Color(0xFF0EA5A4),
      goal: 'Turn stable habits into a resilient financial plan.',
    ),
    LearningTrack(
      id: 'advanced',
      title: 'Advanced',
      subtitle: 'Portfolio strategy, retirement, wealth, and business finance',
      level: 'Deep work',
      iconName: 'stacked_line_chart',
      color: Color(0xFF7C3AED),
      goal: 'Optimize long-term wealth decisions with stronger analysis.',
    ),
    LearningTrack(
      id: 'specialist',
      title: 'Specialist',
      subtitle:
          'Pakistan-specific, Islamic finance, entrepreneurship, and FIRE',
      level: 'Expert focus',
      iconName: 'shield',
      color: Color(0xFFD97706),
      goal:
          'Apply global best practices in local, Shariah-aware, PKR realities.',
    ),
  ];

  static const List<Map<String, dynamic>> marketplacePartners = [
    {
      'id': 'jubilee-insurance',
      'name': 'Jubilee Health Secure',
      'description':
          'Affordable health protection plans for families, freelancers, and salaried professionals across Pakistan.',
      'category': 'Insurance',
      'badge': 'Verified',
      'ctaLabel': 'Explore Cover',
      'colorHex': 0xFF2E3192,
      'iconName': 'shield',
      'websiteUrl': 'https://jubileelife.com/',
      'latitude': 24.8607,
      'longitude': 67.0011,
      'rating': 4.7,
      'reviewCount': 342,
      'trustScore': 94,
      'featured': true,
      'tags': ['Family', 'Cashless', 'Verified'],
      'rateLabel': 'Family cover from PKR 2,500/mo',
      'approvalSpeed': 'Activation in 1-3 business days',
      'estimatedBenefit': 'Reduce out-of-pocket health shocks',
      'minimumIncome': 60000,
      'benefits': [
        'Family and individual health protection',
        'Cashless treatment network signals',
        'Clearer exclusions before handoff',
      ],
      'eligibility': [
        'CNIC required',
        'Family and individual plans available',
        'Medical underwriting may apply',
      ],
      'safetySignals': [
        'Verified by FinEase partner review',
        'Coverage terms reviewed before external handoff',
      ],
      'riskIndicators': ['Confirm waiting periods and exclusions'],
      'status': 'active',
      'approved': true,
      'priority': 1,
    },
    {
      'id': 'hbl-microfinance',
      'name': 'HBL Microfinance Support',
      'description':
          'Microfinance options for women-led households, shopkeepers, and first-time business borrowers.',
      'category': 'Loans',
      'badge': 'Popular',
      'ctaLabel': 'Check Options',
      'colorHex': 0xFF0EA5A4,
      'iconName': 'bank',
      'websiteUrl': 'https://www.hbl.com/',
      'latitude': 24.8607,
      'longitude': 67.0011,
      'rating': 4.5,
      'reviewCount': 288,
      'trustScore': 90,
      'trending': true,
      'tags': ['Low interest', 'Fast approval', 'SME'],
      'rateLabel': 'Indicative markup from 12%-18%',
      'approvalSpeed': 'Indicative decision in 24-72h',
      'estimatedBenefit': 'Faster shortlist for eligible borrowers',
      'minimumIncome': 45000,
      'maxAmount': 500000,
      'benefits': [
        'Microfinance options for shopkeepers',
        'Useful for first-time business borrowers',
        'Documentation guidance before applying',
      ],
      'eligibility': [
        'CNIC holder',
        'Stable income signal preferred',
        'Best for micro and small business use cases',
      ],
      'safetySignals': [
        'Verified partner listing',
        'Application handoff after in-app review',
      ],
      'riskIndicators': [
        'Review repayment affordability before borrowing',
        'Check fees, markup, and late-payment penalties',
      ],
      'status': 'active',
      'approved': true,
      'priority': 2,
    },
    {
      'id': 'rozee-careers',
      'name': 'Career Growth Network',
      'description':
          'Find verified roles, freelance gigs, and upskilling opportunities that improve monthly cash flow.',
      'category': 'Jobs',
      'badge': 'New',
      'ctaLabel': 'View Roles',
      'colorHex': 0xFF059669,
      'iconName': 'briefcase',
      'websiteUrl': 'https://www.rozee.pk/',
      'latitude': 31.5204,
      'longitude': 74.3587,
      'rating': 4.4,
      'reviewCount': 217,
      'trustScore': 86,
      'trending': true,
      'tags': ['Income growth', 'Verified', 'Freelance'],
      'rateLabel': 'Income uplift opportunity',
      'approvalSpeed': 'Shortlisting begins immediately',
      'estimatedBenefit': 'Potential income growth and skill access',
      'benefits': [
        'Verified role and freelance discovery',
        'Better monthly cash-flow options',
        'Early-career and skills pathways',
      ],
      'eligibility': [
        'Suitable for salaried, freelance, and early-career users',
        'Profile completeness improves matching',
      ],
      'safetySignals': [
        'Known marketplace source',
        'Document sharing happens after provider review',
      ],
      'riskIndicators': [
        'Verify hiring terms before sharing sensitive documents',
      ],
      'status': 'active',
      'approved': true,
      'priority': 3,
    },
    {
      'id': 'solar-installments',
      'name': 'Solar Installment Partners',
      'description':
          'Compare installment-based solar solutions to lower electricity costs and protect your household budget.',
      'category': 'Utilities',
      'badge': 'Save More',
      'ctaLabel': 'Compare Plans',
      'colorHex': 0xFFD97706,
      'iconName': 'sun',
      'websiteUrl': 'https://www.lesco.gov.pk/',
      'latitude': 31.5204,
      'longitude': 74.3587,
      'rating': 4.3,
      'reviewCount': 166,
      'trustScore': 84,
      'tags': ['Savings', 'Installments', 'Low bills'],
      'rateLabel': 'Installments from PKR 8,000/mo',
      'approvalSpeed': 'Quote in 1-2 business days',
      'estimatedBenefit': 'Lower monthly utility spend',
      'minimumIncome': 80000,
      'benefits': [
        'Compare installment-based solar solutions',
        'Estimate recurring bill reduction',
        'Prioritize household budget protection',
      ],
      'eligibility': [
        'Homeowner or tenant with service coverage area',
        'Electricity bill history may be requested',
      ],
      'safetySignals': [
        'Provider terms shown before handoff',
        'Budget impact reviewed inside FinEase',
      ],
      'riskIndicators': [
        'Confirm warranty, installation terms, and financing cost',
      ],
      'status': 'active',
      'approved': true,
      'priority': 4,
    },
    {
      'id': 'education-aid',
      'name': 'Education & Scholarship Desk',
      'description':
          'Student financing, scholarships, and training programs designed for Pakistani learners and early professionals.',
      'category': 'Education',
      'badge': 'Featured',
      'ctaLabel': 'See Programs',
      'colorHex': 0xFF7C3AED,
      'iconName': 'school',
      'websiteUrl': 'https://www.hec.gov.pk/',
      'latitude': 33.6844,
      'longitude': 73.0479,
      'rating': 4.6,
      'reviewCount': 198,
      'trustScore': 89,
      'featured': true,
      'tags': ['Eligibility support', 'Scholarships', 'Students'],
      'rateLabel': 'Funding and scholarships available',
      'approvalSpeed': 'Eligibility review within 3-5 days',
      'estimatedBenefit': 'Higher access to funding and upskilling',
      'benefits': [
        'Student financing and scholarship discovery',
        'Eligibility guidance before external forms',
        'Training programs for early professionals',
      ],
      'eligibility': [
        'Students, graduates, or early-career professionals',
        'Program availability varies by province and institution',
      ],
      'safetySignals': [
        'Education source reviewed by FinEase',
        'No sensitive documents requested before provider step',
      ],
      'riskIndicators': ['Confirm deadlines, fees, and scholarship conditions'],
      'status': 'active',
      'approved': true,
      'priority': 5,
    },
  ];

  static List<FinancialTransaction> sampleTransactions() {
    final now = DateTime.now();
    return [
      FinancialTransaction(
        id: 'seed-tx-1',
        title: 'Salary Deposit',
        amount: 325000,
        date: DateTime(now.year, now.month, 1),
        category: 'Income',
        type: 'income',
      ),
      FinancialTransaction(
        id: 'seed-tx-2',
        title: 'Apartment Rent',
        amount: 85000,
        date: DateTime(now.year, now.month, 2),
        category: 'Others',
        type: 'expense',
      ),
      FinancialTransaction(
        id: 'seed-tx-3',
        title: 'Groceries',
        amount: 18500,
        date: now.subtract(const Duration(days: 2)),
        category: 'Groceries',
        type: 'expense',
      ),
      FinancialTransaction(
        id: 'seed-tx-4',
        title: 'Coffee and Breakfast',
        amount: 1200,
        date: now.subtract(const Duration(days: 1)),
        category: 'Groceries',
        type: 'expense',
      ),
      FinancialTransaction(
        id: 'seed-tx-5',
        title: 'Gym Membership',
        amount: 6500,
        date: DateTime(now.year, now.month, 4),
        category: 'Healthcare',
        type: 'expense',
      ),
      FinancialTransaction(
        id: 'seed-tx-6',
        title: 'Streaming Bundle',
        amount: 2100,
        date: DateTime(now.year, now.month, 5),
        category: 'Subscriptions',
        type: 'expense',
      ),
      FinancialTransaction(
        id: 'seed-tx-7',
        title: 'Ride Share',
        amount: 4800,
        date: now.subtract(const Duration(days: 3)),
        category: 'Transport',
        type: 'expense',
      ),
      FinancialTransaction(
        id: 'seed-tx-8',
        title: 'Weekend Dining',
        amount: 9600,
        date: now.subtract(const Duration(days: 4)),
        category: 'Dining',
        type: 'expense',
      ),
      FinancialTransaction(
        id: 'seed-tx-9',
        title: 'Freelance Design',
        amount: 72000,
        date: now.subtract(const Duration(days: 6)),
        category: 'Income',
        type: 'income',
      ),
      FinancialTransaction(
        id: 'seed-tx-10',
        title: 'New Headphones',
        amount: 28500,
        date: now.subtract(const Duration(days: 7)),
        category: 'Entertainment',
        type: 'expense',
      ),
      FinancialTransaction(
        id: 'seed-tx-11',
        title: 'Electric Bill',
        amount: 14200,
        date: now.subtract(const Duration(days: 8)),
        category: 'Electricity',
        type: 'expense',
      ),
      FinancialTransaction(
        id: 'seed-tx-12',
        title: 'Emergency Fund Transfer',
        amount: 25000,
        date: now.subtract(const Duration(days: 9)),
        category: 'Savings',
        type: 'expense',
      ),
    ];
  }

  static List<SavingGoal> sampleGoals() {
    final now = DateTime.now();
    return [
      SavingGoal(
        id: 'seed-goal-1',
        title: 'Emergency Fund',
        targetAmount: 500000,
        currentAmount: 235000,
        targetDate: DateTime(now.year, now.month + 8, 1),
        category: 'Emergency',
        emoji: 'Shield',
      ),
      SavingGoal(
        id: 'seed-goal-2',
        title: 'Japan Trip',
        targetAmount: 420000,
        currentAmount: 165000,
        targetDate: DateTime(now.year + 1, 4, 15),
        category: 'Travel',
        emoji: 'Plane',
      ),
      SavingGoal(
        id: 'seed-goal-3',
        title: 'Investing Starter Fund',
        targetAmount: 300000,
        currentAmount: 118000,
        targetDate: DateTime(now.year, now.month + 5, 10),
        category: 'Others',
        emoji: 'Chart',
      ),
    ];
  }

  static const Map<String, dynamic> sampleProfile = {
    'fullName': 'FinEase Demo',
    'monthlyIncome': 397000.0,
    'targetSavingsRate': 0.22,
  };

  static List<BudgetPlan> sampleBudgetPlans() {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return [
      BudgetPlan(
        id: 'seed-budget-1',
        title: 'Home Essentials',
        category: 'Others',
        allocatedAmount: 95000,
        notes: 'Rent, maintenance, utilities, and internet.',
        monthKey: monthKey,
        createdAt: now,
      ),
      BudgetPlan(
        id: 'seed-budget-2',
        title: 'Food and Groceries',
        category: 'Groceries',
        allocatedAmount: 45000,
        notes: 'Groceries plus weekly dining cap.',
        monthKey: monthKey,
        createdAt: now,
      ),
      BudgetPlan(
        id: 'seed-budget-3',
        title: 'Mobility',
        category: 'Transport',
        allocatedAmount: 18000,
        notes: 'Fuel, ride hailing, and bus fares.',
        monthKey: monthKey,
        createdAt: now,
      ),
      BudgetPlan(
        id: 'seed-budget-4',
        title: 'Family Savings',
        category: 'Savings',
        allocatedAmount: 60000,
        notes: 'Emergency fund and travel contributions.',
        monthKey: monthKey,
        createdAt: now,
      ),
    ];
  }

  static List<LessonCourse> courses = const [
    LessonCourse(
      id: 'budget-foundations',
      title: 'Budget Foundations',
      subtitle: 'Build a monthly plan that survives real life',
      description:
          'Learn how to structure fixed costs, flexible spending, and savings so every paycheck has a job.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=1200&q=80',
      category: 'Budgeting',
      difficulty: 'Starter',
      durationMinutes: 38,
      outcome:
          'Leave with a practical monthly budget and a simple review rhythm.',
      pathLabel: 'Foundation Path',
      rating: 4.8,
      xpReward: 220,
      skillTags: ['Cash flow', 'Planning', 'Savings'],
      lessons: [
        Lesson(
          id: 'bf-1',
          title: 'Give Every Dollar a Job',
          description: 'Set up core budget buckets',
          content:
              'Start with after-tax income, not gross salary. Put essentials first: rent, groceries, utilities, transport, school fees, debt minimums, medicine, and family commitments. Then give savings a job before lifestyle spending starts. A budget is not a punishment; it is a decision map. If your monthly income is PKR 180,000, decide the job for every rupee before the month begins so food delivery, subscriptions, and unplanned shopping do not quietly steal your goals.',
          icon: 'pie_chart',
          points: 40,
          keyTakeaways: [
            'Budget from usable income after deductions.',
            'Essentials, savings, debt, and lifestyle should be separate buckets.',
            'Unassigned money usually becomes accidental spending.',
          ],
          practiceTasks: [
            'Write your monthly take-home income in PKR.',
            'Create four buckets: essentials, savings, debt, and lifestyle.',
            'Assign every rupee to one bucket before the next salary cycle.',
          ],
          caseStudies: [
            'A salaried learner in Islamabad was earning PKR 210,000 but felt broke. After assigning PKR 25,000 to savings on salary day and capping eating out, the month stopped feeling random.',
          ],
          localExample:
              'If take-home pay is PKR 180,000, you might assign PKR 95,000 to essentials, PKR 25,000 to savings, PKR 20,000 to debt, and PKR 40,000 to flexible lifestyle spending.',
        ),
        Lesson(
          id: 'bf-2',
          title: 'The 50/30/20 Rule',
          description: 'Use a ratio as a starting point',
          content:
              'The 50/30/20 rule is a starting framework: up to 50% for needs, up to 30% for wants, and at least 20% for savings or debt payoff. It is not a law. In Karachi, Lahore, Islamabad, or any high-rent situation, needs may temporarily sit at 60%. The skill is not forcing the exact ratio; the skill is noticing the trade-off and building a realistic path back toward savings.',
          icon: 'balance',
          points: 40,
          keyTakeaways: [
            'The ratio is a benchmark, not a moral score.',
            'High essential costs require honest adjustment.',
            'Savings rate should improve as income rises or debt falls.',
          ],
          practiceTasks: [
            'Calculate your current needs, wants, and savings percentages.',
            'Choose one category to adjust by 3-5% next month.',
          ],
          mythBusters: [
            'Myth: If you cannot hit 50/30/20, budgeting has failed. Reality: the ratio helps diagnose pressure and choose the next move.',
          ],
          localExample:
              'A PKR 160,000 earner paying PKR 70,000 rent may use 60/20/20 temporarily while working on income growth or lower fixed costs.',
        ),
        Lesson(
          id: 'bf-3',
          title: 'Sinking Funds',
          description: 'Plan for irregular expenses',
          content:
              'Sinking funds are mini savings buckets for predictable but irregular costs. Annual insurance, Eid spending, school fees, car maintenance, phone replacement, wedding gifts, and home repairs are not emergencies if you can see them coming. Divide the expected cost by the number of months left, then transfer that amount monthly. This turns panic payments into planned payments.',
          icon: 'wallet',
          points: 60,
          keyTakeaways: [
            'Predictable expenses should not drain emergency savings.',
            'Monthly transfers make large future bills feel smaller.',
            'Separate sinking funds by purpose so money stays clear.',
          ],
          practiceTasks: [
            'List three annual or seasonal costs coming in the next 12 months.',
            'Divide each cost by the number of months remaining.',
            'Create one separate bucket for the largest upcoming cost.',
          ],
          templates: ['Annual expense calendar'],
          localExample:
              'If school fees of PKR 90,000 are due in six months, save PKR 15,000 per month instead of scrambling in the due month.',
        ),
      ],
      quiz: CourseQuiz(
        id: 'bf-quiz',
        title: 'Budget Foundations Quiz',
        questions: [
          QuizQuestion(
            id: 'bf-q1',
            prompt: 'What is the main purpose of a sinking fund?',
            options: [
              'Pay off credit cards faster',
              'Set aside money for irregular planned costs',
              'Track investment returns',
              'Reduce taxes immediately',
            ],
            correctIndex: 1,
            explanation:
                'Sinking funds smooth predictable but non-monthly expenses like car repairs or insurance renewals.',
          ),
          QuizQuestion(
            id: 'bf-q2',
            prompt: 'Which statement about 50/30/20 is strongest?',
            options: [
              'It fits every household permanently',
              'It only works for high earners',
              'It is a flexible benchmark to adjust',
              'It excludes savings goals',
            ],
            correctIndex: 2,
            explanation:
                'The ratio is useful as a baseline, but it should adapt to cost of living and goals.',
          ),
        ],
      ),
      externalUrl:
          'https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:budgeting-and-saving',
      videoUrl:
          'https://www.youtube.com/results?search_query=50+30+20+budgeting+rule+Khan+Academy',
      trackId: 'beginner',
      localRelevance:
          'Uses PKR salary cycles, rent, grocery inflation, and family support realities.',
      capstone: 'Create a one-month PKR budget with a weekly review rule.',
    ),
    LessonCourse(
      id: 'smart-investing',
      title: 'Smart Investing',
      subtitle: 'Understand risk, diversification, and long-term growth',
      description:
          'Move from saving cash to building an investing framework with index funds, time horizon, and risk control.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1640161704729-cbe966a08476?auto=format&fit=crop&w=1200&q=80',
      category: 'Investing',
      difficulty: 'Intermediate',
      durationMinutes: 45,
      outcome:
          'Build an investing framework around time horizon, risk, and diversification.',
      pathLabel: 'Growth Path',
      rating: 4.9,
      xpReward: 260,
      skillTags: ['Risk', 'Index funds', 'Allocation'],
      lessons: [
        Lesson(
          id: 'si-1',
          title: 'Risk and Return',
          description: 'Why higher upside usually means higher volatility',
          content:
              'Investment risk is the price paid for expected growth. Cash feels safe in the short term but loses buying power when inflation is high. Stocks and equity funds can grow more, but their prices move sharply. The correct question is not "Which investment is best?" It is "When do I need this money, and how much decline can I survive without selling?" Match investments to time horizon first.',
          icon: 'trending_up',
          points: 50,
          keyTakeaways: [
            'Higher expected return usually brings higher volatility.',
            'Short-term money should not depend on risky markets.',
            'Risk capacity depends on time horizon, income stability, and emergency savings.',
          ],
          practiceTasks: [
            'Label each goal as under 1 year, 1-5 years, or 5+ years.',
            'Write the maximum temporary decline you could tolerate.',
          ],
          mythBusters: [
            'Myth: Risk means something is bad. Reality: unmanaged risk is bad; intentional risk can fund long-term growth.',
          ],
          localExample:
              'Money needed for university fees next year should be treated differently from retirement money needed decades later.',
        ),
        Lesson(
          id: 'si-2',
          title: 'Index Funds Explained',
          description: 'A beginner-friendly core holding',
          content:
              'An index fund owns a basket of investments that follows a market index. Instead of trying to pick one winning company, the investor owns many companies through one fund. This lowers single-company risk and usually keeps fees lower than active management. Indexing is not magic and does not remove market declines, but it is a disciplined way to participate in broad market growth.',
          icon: 'stacked_line_chart',
          points: 50,
          keyTakeaways: [
            'Index funds reduce dependence on one company.',
            'Fees matter because they compound against you.',
            'Diversification helps, but it does not remove market risk.',
          ],
          practiceTasks: [
            'Compare two funds by holdings, fee, and benchmark.',
            'Write whether the fund fits a short, medium, or long-term goal.',
          ],
          caseStudies: [
            'A beginner investor avoids hot stock tips and starts by learning what a broad market fund actually owns.',
          ],
        ),
        Lesson(
          id: 'si-3',
          title: 'Asset Allocation',
          description: 'Balance growth and stability',
          content:
              'Asset allocation is the mix between growth, stability, and liquidity. Stocks or equity funds usually drive long-term growth. Bonds, sukuk, or fixed-income funds can reduce volatility. Cash supports near-term needs. A strong allocation lets you stay invested during bad headlines because every rupee has a job: spend soon, protect, or grow.',
          icon: 'donut_large',
          points: 70,
          keyTakeaways: [
            'Allocation matters more than chasing one perfect product.',
            'Cash, fixed income, and equities serve different jobs.',
            'Revisit allocation when goals or timelines change.',
          ],
          practiceTasks: [
            'Draw your current asset mix as cash, fixed income, equity, and other.',
            'Mark which assets support goals due within two years.',
          ],
          localExample:
              'A Pakistani investor may hold PKR cash for near-term needs, fixed-income or sukuk exposure for stability, and long-term growth assets for future goals.',
        ),
      ],
      quiz: CourseQuiz(
        id: 'si-quiz',
        title: 'Smart Investing Quiz',
        questions: [
          QuizQuestion(
            id: 'si-q1',
            prompt: 'Why do many beginners start with index funds?',
            options: [
              'They guarantee profits',
              'They remove all volatility',
              'They provide broad diversification',
              'They eliminate taxes',
            ],
            correctIndex: 2,
            explanation:
                'Index funds help diversify across many holdings rather than relying on one company.',
          ),
          QuizQuestion(
            id: 'si-q2',
            prompt: 'What should influence your stock/bond mix most?',
            options: [
              'Your friend’s portfolio',
              'Your time horizon and risk tolerance',
              'The latest social media trend',
              'Only this month’s market move',
            ],
            correctIndex: 1,
            explanation:
                'Time horizon and ability to handle volatility are the primary asset-allocation inputs.',
          ),
        ],
      ),
      externalUrl: 'https://www.investopedia.com/terms/i/indexfund.asp',
      videoUrl:
          'https://www.youtube.com/results?search_query=index+funds+asset+allocation+investing+for+beginners',
      trackId: 'intermediate',
      prerequisites: ['Budget Foundations', 'Emergency Fund Systems'],
      localRelevance:
          'Connects global diversification principles with Pakistani inflation and PKR currency risk.',
      capstone: 'Draft a starter investment policy statement.',
    ),
    LessonCourse(
      id: 'credit-and-debt',
      title: 'Credit and Debt',
      subtitle: 'Borrow strategically and protect your score',
      description:
          'Understand how utilization, payment history, and debt payoff methods affect your financial flexibility.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&w=1200&q=80',
      category: 'Credit',
      difficulty: 'Starter',
      durationMinutes: 32,
      outcome:
          'Know how to protect your score and choose a payoff method with intent.',
      pathLabel: 'Resilience Path',
      rating: 4.7,
      xpReward: 180,
      skillTags: ['Credit score', 'Debt payoff', 'Borrowing'],
      lessons: [
        Lesson(
          id: 'cd-1',
          title: 'How Credit Scores Work',
          description: 'The major factors behind your score',
          content:
              'Creditworthiness is built through trust signals: paying on time, using only a manageable share of available credit, keeping records clean, and avoiding desperate borrowing patterns. Even when a formal score is not central, banks, lenders, landlords, and business partners still evaluate reliability. Missing payments damages trust quickly because it signals cash-flow stress.',
          icon: 'credit_score',
          points: 40,
          keyTakeaways: [
            'On-time payments are the strongest trust signal.',
            'High utilization can make a borrower look stretched.',
            'Credit health is useful even before you need a loan.',
          ],
          practiceTasks: [
            'List all recurring debt payments and due dates.',
            'Set reminders three days before each due date.',
          ],
          localExample:
              'A missed installment on a phone, bike, or personal loan can affect future borrowing conversations even if the amount feels small.',
        ),
        Lesson(
          id: 'cd-2',
          title: 'Avalanche vs Snowball',
          description: 'Choose a debt payoff method',
          content:
              'Debt avalanche pays extra toward the highest-interest debt first, which usually saves the most money. Debt snowball pays extra toward the smallest balance first, which creates faster emotional wins. The best method is the one you can actually follow. If stress is high, snowball may build momentum; if discipline is strong, avalanche usually wins mathematically.',
          icon: 'compare_arrows',
          points: 40,
          keyTakeaways: [
            'Avalanche minimizes total interest.',
            'Snowball builds motivation through quick wins.',
            'Minimum payments continue on every debt in both methods.',
          ],
          practiceTasks: [
            'List debts by balance, markup or interest rate, and minimum payment.',
            'Choose avalanche or snowball and name the first target debt.',
          ],
          caseStudies: [
            'A borrower with three debts starts with the smallest balance to feel progress, then switches to avalanche after one debt is cleared.',
          ],
        ),
        Lesson(
          id: 'cd-3',
          title: 'Use Debt Without Letting It Use You',
          description: 'Rules for responsible borrowing',
          content:
              'Debt is not automatically evil, but it must have a purpose, a payoff path, and a payment that does not choke the household. Borrowing for productive education, a business asset, or urgent medical need is different from borrowing to maintain appearances. Before borrowing, test the payment against income, emergency savings, and family obligations.',
          icon: 'shield',
          points: 50,
          keyTakeaways: [
            'Borrow only with a written payoff path.',
            'Monthly affordability is not the same as total affordability.',
            'Debt should improve stability or solve a real need.',
          ],
          practiceTasks: [
            'Calculate the payment as a percentage of take-home income.',
            'Compare total repayment, not only monthly installment.',
          ],
          mythBusters: [
            'Myth: If the monthly payment fits, the loan is safe. Reality: total repayment and income risk matter too.',
          ],
          localExample:
              'A PKR 18,000 monthly installment may look affordable until rent, groceries, fuel, school fees, and family support are included.',
        ),
      ],
      quiz: CourseQuiz(
        id: 'cd-quiz',
        title: 'Credit and Debt Quiz',
        questions: [
          QuizQuestion(
            id: 'cd-q1',
            prompt:
                'Which payoff method usually reduces total interest the most?',
            options: [
              'Debt avalanche',
              'Debt snowball',
              'Minimum payments only',
              'Balance transfers without a plan',
            ],
            correctIndex: 0,
            explanation:
                'Avalanche targets the highest-interest debt first, which lowers total interest over time.',
          ),
          QuizQuestion(
            id: 'cd-q2',
            prompt: 'What is credit utilization?',
            options: [
              'Your salary spent on rent',
              'Your used revolving credit versus total limit',
              'Your savings rate',
              'Your interest earned',
            ],
            correctIndex: 1,
            explanation:
                'Utilization measures how much of your revolving credit line you are using.',
          ),
        ],
      ),
      externalUrl:
          'https://www.consumerfinance.gov/consumer-tools/debt-collection/',
      videoUrl:
          'https://www.youtube.com/results?search_query=debt+avalanche+vs+debt+snowball+explained',
      trackId: 'beginner',
      localRelevance:
          'Uses installment plans, salary advances, BNPL, and family borrowing examples.',
      capstone: 'Choose a payoff method and map the first 90 days.',
    ),
    LessonCourse(
      id: 'pakistan-finance-playbook',
      title: 'Pakistan Finance Playbook',
      subtitle: 'Budget, save, and borrow using real local realities',
      description:
          'Learn how to manage salary cycles, inflation pressure, committee savings, and responsible borrowing in Pakistan.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=80',
      category: 'Local Finance',
      difficulty: 'Starter',
      durationMinutes: 34,
      outcome:
          'Adapt budgeting, saving, and borrowing decisions to local Pakistani realities.',
      pathLabel: 'Local Money Path',
      rating: 4.9,
      xpReward: 210,
      skillTags: ['Inflation', 'PKR savings', 'Loan choices'],
      lessons: [
        Lesson(
          id: 'pf-1',
          title: 'Budgeting for Inflation',
          description: 'Protect essentials when prices move fast',
          content:
              'In Pakistan, a monthly budget can go stale quickly when groceries, fuel, school transport, utilities, and medicines move faster than expected. Separate fixed costs from volatile essentials. Fixed costs need negotiation or structural change; volatile essentials need weekly review. A weekly grocery and fuel check prevents the shock from appearing only at month-end.',
          icon: 'pie_chart',
          points: 45,
          keyTakeaways: [
            'Inflation first shows up in flexible essential categories.',
            'Weekly reviews beat monthly regret.',
            'A buffer category protects the rest of the plan.',
          ],
          practiceTasks: [
            'Choose three categories to review every Friday.',
            'Add a small inflation buffer before lifestyle spending.',
          ],
          localExample:
              'If groceries drift from PKR 38,000 to PKR 47,000, adjust weekly meals and supplier choices before the full month breaks.',
        ),
        Lesson(
          id: 'pf-2',
          title: 'Emergency Funds in PKR',
          description: 'Build a cushion before chasing returns',
          content:
              'A PKR emergency fund should be boring, accessible, and separate from daily spending. The point is not to beat inflation; the point is to avoid high-cost debt when salary is delayed, a client pays late, a medical bill appears, or a family emergency lands. Start with one month of core expenses, then build toward three to six months.',
          icon: 'shield',
          points: 55,
          keyTakeaways: [
            'Emergency money needs access and stability.',
            'One month is a meaningful starter target.',
            'Separate emergency funds from planned annual costs.',
          ],
          practiceTasks: [
            'Calculate one month of core household costs.',
            'Set the next salary-day transfer amount.',
          ],
          caseStudies: [
            'A freelancer in Lahore avoids taking a salary advance because two months of expenses are already reserved.',
          ],
        ),
        Lesson(
          id: 'pf-3',
          title: 'Borrowing Carefully',
          description: 'Compare markup, tenure, and real repayment pressure',
          content:
              'In local loan ads, the monthly installment often gets more attention than total repayment. That is dangerous. Compare markup, fees, tenure, late penalties, collateral, and total amount paid. Also check whether the loan improves your financial position or simply moves pressure into the future. Good borrowing solves a real problem without trapping future income.',
          icon: 'credit_score',
          points: 60,
          keyTakeaways: [
            'Monthly installment is only one part of the decision.',
            'Total repayment reveals the real cost.',
            'Borrowing should have a purpose and exit plan.',
          ],
          practiceTasks: [
            'Compare two loan offers by total repayment and tenure.',
            'Write the reason the loan improves or protects your finances.',
          ],
          mythBusters: [
            'Myth: Longer tenure is always easier. Reality: it can lower the payment but raise the total cost.',
          ],
          localExample:
              'A PKR 500,000 loan can feel manageable monthly but become expensive if the tenure is stretched and fees are ignored.',
        ),
      ],
      quiz: CourseQuiz(
        id: 'pf-quiz',
        title: 'Pakistan Finance Playbook Quiz',
        questions: [
          QuizQuestion(
            id: 'pf-q1',
            prompt:
                'Which category should be reviewed most often during inflation?',
            options: [
              'Volatile essentials like groceries and fuel',
              'Only annual subscriptions',
              'Only charitable giving',
              'None, budgets should stay fixed all year',
            ],
            correctIndex: 0,
            explanation:
                'Fast-moving essential categories drift first, so they need more frequent review.',
          ),
          QuizQuestion(
            id: 'pf-q2',
            prompt: 'What should you compare before taking a loan?',
            options: [
              'Only the monthly installment',
              'Total repayment, markup, and income impact',
              'Only the loan advertisement',
              'Only the branch location',
            ],
            correctIndex: 1,
            explanation:
                'A strong loan decision checks the total cost and affordability, not just the headline installment.',
          ),
        ],
      ),
      externalUrl: 'https://www.sbp.org.pk/finc/FL.asp',
      videoUrl:
          'https://www.youtube.com/results?search_query=personal+finance+Pakistan+budgeting+saving+borrowing',
      trackId: 'specialist',
      localRelevance:
          'Built around Pakistani salary timing, fuel and grocery volatility, committee savings, and markup comparisons.',
      capstone: 'Build a Pakistan-specific monthly money operating system.',
    ),
    LessonCourse(
      id: 'emergency-fund-systems',
      title: 'Emergency Fund Systems',
      subtitle: 'Build a shock absorber before life tests your budget',
      description:
          'Design the right cash buffer, automate savings, and decide where to keep money you may need quickly.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1579621970795-87facc2f976d?auto=format&fit=crop&w=1200&q=80',
      category: 'Saving',
      difficulty: 'Starter',
      durationMinutes: 42,
      outcome:
          'Know your emergency fund target, storage rules, and first automated transfer.',
      pathLabel: 'Foundation Path',
      rating: 4.8,
      xpReward: 230,
      skillTags: ['Emergency fund', 'Automation', 'Cash buffer'],
      lessons: [
        Lesson(
          id: 'efs-1',
          title: 'Your Real Safety Number',
          description: 'Calculate three, six, and nine month targets',
          content:
              'Start with core monthly expenses: rent, groceries, utilities, transport, school fees, medicine, and debt payments. Your first target is one month. Your strong target is three to six months.',
          icon: 'shield',
          points: 45,
          keyTakeaways: [
            'Emergency funds protect decisions, not just bills.',
            'Core expenses are different from lifestyle spending.',
            'A one-month starter fund creates early psychological safety.',
          ],
          practiceTasks: [
            'List your non-negotiable monthly costs in PKR.',
            'Calculate one-month and three-month emergency targets.',
          ],
          calculators: ['Emergency fund target calculator'],
          localExample:
              'If core household costs are PKR 115,000, a starter fund is PKR 115,000 and a three-month fund is PKR 345,000.',
        ),
        Lesson(
          id: 'efs-2',
          title: 'Automate Before Motivation Fades',
          description: 'Turn saving into a monthly default',
          content:
              'Move money out on salary day before it blends into daily spending. Use a separate account or wallet pocket so the fund is visible but not tempting.',
          icon: 'wallet',
          points: 50,
          practiceTasks: [
            'Choose a fixed transfer amount for the next salary cycle.',
            'Name the account or goal Emergency Fund so it has a job.',
          ],
          mythBusters: [
            'Myth: Small transfers do not matter. Reality: consistency builds the first buffer.',
            'Myth: Emergency funds should chase high returns. Reality: liquidity matters more.',
          ],
          templates: ['Salary-day savings rule'],
        ),
        Lesson(
          id: 'efs-3',
          title: 'When To Use It',
          description: 'Separate emergencies from expected expenses',
          content:
              'Medical shocks, job gaps, urgent repairs, or family crises qualify. Eid, school fees, annual insurance, and device upgrades should be sinking funds instead.',
          icon: 'balance',
          points: 55,
          caseStudies: [
            'A Lahore freelancer keeps PKR 250,000 aside after one delayed client payment caused two months of stress.',
          ],
          applicationTools: ['Emergency or sinking fund decision card'],
        ),
      ],
      quiz: CourseQuiz(
        id: 'efs-quiz',
        title: 'Emergency Fund Systems Quiz',
        questions: [
          QuizQuestion(
            id: 'efs-q1',
            prompt: 'What should an emergency fund prioritize first?',
            options: [
              'Maximum investment return',
              'Fast access and stability',
              'Buying discounts',
              'Speculative growth',
            ],
            correctIndex: 1,
            explanation:
                'Emergency money must be available when life breaks the plan.',
          ),
          QuizQuestion(
            id: 'efs-q2',
            prompt: 'Which cost is better handled by a sinking fund?',
            options: [
              'A sudden hospital visit',
              'Job loss',
              'Annual school fees',
              'Emergency car repair',
            ],
            correctIndex: 2,
            explanation:
                'Predictable non-monthly costs should be planned before they arrive.',
          ),
        ],
      ),
      externalUrl:
          'https://www.consumerfinance.gov/consumer-tools/saving-money/',
      videoUrl:
          'https://www.youtube.com/results?search_query=emergency+fund+explained+personal+finance',
      trackId: 'beginner',
      prerequisites: ['Budget Foundations'],
      localRelevance:
          'Uses PKR emergency targets, family support obligations, and delayed income examples.',
      capstone: 'Create a two-stage emergency fund plan.',
    ),
    LessonCourse(
      id: 'spending-behavior-lab',
      title: 'Spending Behavior Lab',
      subtitle: 'Understand why budgets fail and design better habits',
      description:
          'Learn the psychology of impulse spending, social pressure, and decision fatigue so your money plan survives real life.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1554224154-26032ffc0d07?auto=format&fit=crop&w=1200&q=80',
      category: 'Behavior',
      difficulty: 'Starter',
      durationMinutes: 36,
      outcome:
          'Identify your top spending triggers and build a weekly money reset ritual.',
      pathLabel: 'Foundation Path',
      rating: 4.7,
      xpReward: 190,
      skillTags: ['Habits', 'Impulse control', 'Weekly review'],
      lessons: [
        Lesson(
          id: 'sbl-1',
          title: 'Find Your Spending Triggers',
          description: 'Spot emotional and social spending patterns',
          content:
              'Every overspend has a trigger: fatigue, boredom, convenience, family pressure, or status. Track the moment before the purchase, not only the purchase itself.',
          icon: 'pie_chart',
          points: 40,
          practiceTasks: [
            'Mark three recent purchases as need, joy, pressure, or fatigue.',
            'Create one friction rule for your biggest trigger.',
          ],
          templates: ['Trigger audit worksheet'],
        ),
        Lesson(
          id: 'sbl-2',
          title: 'The 24-Hour Pause',
          description: 'Use delay as a financial defense',
          content:
              'For non-essential purchases above a threshold, wait one day. The goal is not deprivation. The goal is buying with a clear mind.',
          icon: 'balance',
          points: 45,
          mythBusters: [
            'Myth: Discipline means never enjoying money. Reality: good spending is planned spending.',
          ],
          applicationTools: ['Pause threshold rule'],
        ),
        Lesson(
          id: 'sbl-3',
          title: 'Weekly Money Reset',
          description: 'Make progress visible before the month ends',
          content:
              'A five-minute weekly reset checks category drift, upcoming bills, and one decision for next week. Monthly reviews are often too late.',
          icon: 'wallet',
          points: 45,
          caseStudies: [
            'A Karachi household reduced food delivery spending by setting a Friday review and a weekly dining cap.',
          ],
        ),
      ],
      quiz: CourseQuiz(
        id: 'sbl-quiz',
        title: 'Spending Behavior Lab Quiz',
        questions: [
          QuizQuestion(
            id: 'sbl-q1',
            prompt: 'What should you track to understand impulse spending?',
            options: [
              'Only the amount spent',
              'The trigger before the purchase',
              'Only the store name',
              'Only your monthly income',
            ],
            correctIndex: 1,
            explanation:
                'Triggers reveal why the purchase happened and how to design friction.',
          ),
          QuizQuestion(
            id: 'sbl-q2',
            prompt: 'Why do weekly reviews help?',
            options: [
              'They replace income',
              'They catch drift before month-end',
              'They remove all bills',
              'They guarantee investment returns',
            ],
            correctIndex: 1,
            explanation:
                'Short review cycles make small corrections easier and less stressful.',
          ),
        ],
      ),
      externalUrl:
          'https://www.consumerfinance.gov/consumer-tools/managing-your-money/',
      videoUrl:
          'https://www.youtube.com/results?search_query=psychology+of+spending+money+personal+finance',
      trackId: 'beginner',
      localRelevance:
          'Includes food delivery, weddings, family expectations, and status purchases in PKR.',
      capstone: 'Build one spending rule for your biggest trigger.',
    ),
    LessonCourse(
      id: 'insurance-risk-protection',
      title: 'Insurance and Risk Protection',
      subtitle: 'Protect your household from expensive surprises',
      description:
          'Understand health, life, property, and income protection decisions without overbuying or staying exposed.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?auto=format&fit=crop&w=1200&q=80',
      category: 'Protection',
      difficulty: 'Intermediate',
      durationMinutes: 48,
      outcome:
          'Prioritize the protection products that match your household risk.',
      pathLabel: 'Protection Path',
      rating: 4.8,
      xpReward: 240,
      skillTags: ['Insurance', 'Risk', 'Family protection'],
      lessons: [
        Lesson(
          id: 'irp-1',
          title: 'Risk Transfer Basics',
          description: 'Know which risks to insure and which to self-fund',
          content:
              'Insurance makes sense when a low-probability event would create a high-cost loss. Smaller predictable costs are better handled with savings.',
          icon: 'shield',
          points: 55,
          keyTakeaways: [
            'Insure catastrophic risks first.',
            'Deductibles and exclusions matter as much as premiums.',
          ],
          calculators: ['Coverage priority matrix'],
        ),
        Lesson(
          id: 'irp-2',
          title: 'Reading Policy Fine Print',
          description: 'Compare exclusions, waiting periods, and claim rules',
          content:
              'A cheap policy can be expensive if it excludes the risk you actually face. Compare claim process, hospital network, exclusions, and renewal rules.',
          icon: 'balance',
          points: 55,
          practiceTasks: [
            'Compare two policies using premium, coverage, exclusions, and claim process.',
          ],
          templates: ['Policy comparison checklist'],
        ),
        Lesson(
          id: 'irp-3',
          title: 'Family Protection Map',
          description: 'Decide coverage based on dependents and obligations',
          content:
              'A person with dependents needs a different plan than a single earner with no debt. Cover income replacement, medical shocks, and major liabilities.',
          icon: 'wallet',
          points: 60,
          caseStudies: [
            'A sole earner in Faisalabad maps school fees and rent before choosing life cover.',
          ],
        ),
      ],
      quiz: CourseQuiz(
        id: 'irp-quiz',
        title: 'Insurance and Risk Protection Quiz',
        questions: [
          QuizQuestion(
            id: 'irp-q1',
            prompt: 'Which risk should usually be insured first?',
            options: [
              'Tiny routine repairs',
              'Low-cost predictable purchases',
              'Catastrophic losses a family cannot absorb',
              'Monthly entertainment',
            ],
            correctIndex: 2,
            explanation:
                'Insurance is strongest for severe losses that would damage household stability.',
          ),
          QuizQuestion(
            id: 'irp-q2',
            prompt: 'What can make a cheap policy risky?',
            options: [
              'Clear claim process',
              'Strong hospital network',
              'Important exclusions',
              'Transparent renewal rules',
            ],
            correctIndex: 2,
            explanation:
                'Exclusions can remove protection exactly where the family needs it.',
          ),
        ],
      ),
      externalUrl: 'https://www.investopedia.com/insurance-4427716',
      videoUrl:
          'https://www.youtube.com/results?search_query=insurance+basics+health+life+personal+finance',
      trackId: 'intermediate',
      prerequisites: ['Emergency Fund Systems'],
      localRelevance:
          'Frames decisions around Pakistani hospital networks, family dependents, and claim reliability.',
      capstone: 'Create a household risk protection map.',
    ),
    LessonCourse(
      id: 'tax-salary-planning-pakistan',
      title: 'Pakistan Tax and Salary Planning',
      subtitle: 'Understand filer status, salary tax, and documentation',
      description:
          'Learn the practical tax basics a Pakistani earner needs: records, deductions, withholding, and filer awareness.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1200&q=80',
      category: 'Taxes',
      difficulty: 'Intermediate',
      durationMinutes: 52,
      outcome:
          'Build a clean tax document folder and understand how tax affects real take-home pay.',
      pathLabel: 'Pakistan Money Path',
      rating: 4.9,
      xpReward: 270,
      skillTags: ['Taxes', 'Filer status', 'Salary planning'],
      lessons: [
        Lesson(
          id: 'tsp-1',
          title: 'Gross Pay vs Take-Home Pay',
          description: 'See how deductions change your real income',
          content:
              'A salary offer is not the same as usable monthly cash. Track tax, provident fund, loan deductions, and any reimbursements separately.',
          icon: 'receipt',
          points: 55,
          calculators: ['Take-home pay estimator'],
          localExample:
              'A PKR 250,000 gross salary can feel very different after withholding, provident fund, and transport costs.',
        ),
        Lesson(
          id: 'tsp-2',
          title: 'Filer Awareness',
          description: 'Know why documentation matters',
          content:
              'Filer status can affect withholding and financial credibility. Keep salary certificates, bank statements, tax certificates, and investment records organized.',
          icon: 'stacked_line_chart',
          points: 60,
          templates: ['Annual tax document checklist'],
          mythBusters: [
            'Myth: Taxes matter only for business owners. Reality: salaried people also need records and planning.',
          ],
        ),
        Lesson(
          id: 'tsp-3',
          title: 'Planning Without Guesswork',
          description: 'Use records to make better money decisions',
          content:
              'A tax folder helps with loan applications, visa paperwork, business registration, and investment tracking. Good records reduce stress.',
          icon: 'wallet',
          points: 55,
          applicationTools: ['Document folder map'],
        ),
      ],
      quiz: CourseQuiz(
        id: 'tsp-quiz',
        title: 'Pakistan Tax and Salary Planning Quiz',
        questions: [
          QuizQuestion(
            id: 'tsp-q1',
            prompt: 'What is take-home pay?',
            options: [
              'Gross salary before deductions',
              'Money available after deductions',
              'Only annual bonus',
              'Only tax refund',
            ],
            correctIndex: 1,
            explanation:
                'Take-home pay is what actually reaches your usable monthly cash flow.',
          ),
          QuizQuestion(
            id: 'tsp-q2',
            prompt: 'Why keep a tax document folder?',
            options: [
              'To avoid budgeting',
              'To support filings, loans, and financial decisions',
              'To increase spending',
              'To replace emergency savings',
            ],
            correctIndex: 1,
            explanation:
                'Organized records make tax, credit, and planning decisions easier.',
          ),
        ],
      ),
      externalUrl: 'https://www.fbr.gov.pk/',
      videoUrl:
          'https://www.youtube.com/results?search_query=Pakistan+income+tax+filer+non+filer+basics',
      trackId: 'intermediate',
      prerequisites: ['Budget Foundations'],
      localRelevance:
          'Focused on Pakistani salary records, filer awareness, withholding, and PKR planning.',
      capstone: 'Build a tax-ready document folder for the current year.',
    ),
    LessonCourse(
      id: 'portfolio-construction',
      title: 'Portfolio Construction',
      subtitle: 'Move from random investments to an intentional strategy',
      description:
          'Build a portfolio around goals, time horizon, diversification, rebalancing, and risk controls.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=80',
      category: 'Investing',
      difficulty: 'Advanced',
      durationMinutes: 64,
      outcome: 'Create an investment policy statement and a rebalancing rule.',
      pathLabel: 'Wealth Path',
      rating: 4.9,
      xpReward: 330,
      skillTags: ['Asset allocation', 'Rebalancing', 'Risk control'],
      lessons: [
        Lesson(
          id: 'pc-1',
          title: 'Goals Before Products',
          description: 'Match each investment to a time horizon',
          content:
              'Before choosing assets, define the job: emergency money, home down payment, education, retirement, or wealth growth. Different jobs need different risk.',
          icon: 'donut_large',
          points: 65,
          practiceTasks: [
            'Label each current investment with its goal and time horizon.',
          ],
          templates: ['Investment policy statement starter'],
        ),
        Lesson(
          id: 'pc-2',
          title: 'Rebalancing Rules',
          description: 'Control drift without chasing headlines',
          content:
              'Rebalancing brings a portfolio back to target allocation. Use calendar rules or percentage bands instead of emotional reactions.',
          icon: 'compare_arrows',
          points: 70,
          calculators: ['Rebalancing band calculator'],
        ),
        Lesson(
          id: 'pc-3',
          title: 'Currency and Concentration Risk',
          description: 'Think beyond one market and one currency',
          content:
              'PKR savers face local inflation and currency risk. Diversification can include asset classes, sectors, geographies, and liquidity buckets.',
          icon: 'trending_up',
          points: 70,
          caseStudies: [
            'A family saving for overseas education separates PKR near-term cash from long-term growth assets.',
          ],
        ),
      ],
      quiz: CourseQuiz(
        id: 'pc-quiz',
        title: 'Portfolio Construction Quiz',
        questions: [
          QuizQuestion(
            id: 'pc-q1',
            prompt: 'What should come before choosing an investment product?',
            options: [
              'Social media hype',
              'A defined goal and time horizon',
              'Only last month performance',
              'A friend recommendation',
            ],
            correctIndex: 1,
            explanation:
                'The goal determines liquidity needs, risk capacity, and suitable assets.',
          ),
          QuizQuestion(
            id: 'pc-q2',
            prompt: 'What does rebalancing do?',
            options: [
              'Guarantees profits',
              'Returns allocation toward target weights',
              'Eliminates all risk',
              'Avoids taxes automatically',
            ],
            correctIndex: 1,
            explanation:
                'Rebalancing controls portfolio drift and supports discipline.',
          ),
        ],
      ),
      externalUrl: 'https://www.investopedia.com/portfolio-management-4689745',
      videoUrl:
          'https://www.youtube.com/results?search_query=portfolio+construction+asset+allocation+rebalancing',
      trackId: 'advanced',
      prerequisites: ['Smart Investing'],
      localRelevance:
          'Covers PKR inflation, currency exposure, and concentration risk for Pakistani investors.',
      capstone: 'Write a one-page investment policy statement.',
    ),
    LessonCourse(
      id: 'retirement-fire-planning',
      title: 'Retirement and FIRE Planning',
      subtitle: 'Calculate freedom targets and long-term contribution plans',
      description:
          'Learn retirement math, withdrawal rates, inflation assumptions, and sustainable contribution habits.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
      category: 'Retirement',
      difficulty: 'Advanced',
      durationMinutes: 58,
      outcome:
          'Estimate a retirement number and monthly contribution gap in PKR.',
      pathLabel: 'Wealth Path',
      rating: 4.8,
      xpReward: 310,
      skillTags: ['Retirement', 'FIRE', 'Compounding'],
      lessons: [
        Lesson(
          id: 'rfp-1',
          title: 'Your Freedom Number',
          description: 'Estimate how much capital future you needs',
          content:
              'A retirement number depends on annual spending, inflation, expected returns, family responsibilities, and desired safety margin.',
          icon: 'stacked_line_chart',
          points: 65,
          calculators: ['Retirement number estimator'],
        ),
        Lesson(
          id: 'rfp-2',
          title: 'Contribution Rate Design',
          description: 'Turn a distant goal into a monthly action',
          content:
              'A contribution plan connects current income to future independence. Increase contributions after raises before lifestyle inflation absorbs them.',
          icon: 'wallet',
          points: 65,
          practiceTasks: [
            'Calculate your current monthly investing rate as a percentage of income.',
          ],
        ),
        Lesson(
          id: 'rfp-3',
          title: 'Withdrawal Rate Caution',
          description: 'Understand why rules are starting points',
          content:
              'Withdrawal rules are not guarantees. Local inflation, currency risk, taxes, and family support can require a larger margin.',
          icon: 'shield',
          points: 65,
          mythBusters: [
            'Myth: One global retirement rule fits every country. Reality: assumptions need local adjustment.',
          ],
        ),
      ],
      quiz: CourseQuiz(
        id: 'rfp-quiz',
        title: 'Retirement and FIRE Planning Quiz',
        questions: [
          QuizQuestion(
            id: 'rfp-q1',
            prompt: 'What shapes a retirement number?',
            options: [
              'Only age',
              'Future spending, inflation, returns, and safety margin',
              'Only current rent',
              'Only bank balance today',
            ],
            correctIndex: 1,
            explanation:
                'Retirement planning combines future expenses, assumptions, and risk buffers.',
          ),
          QuizQuestion(
            id: 'rfp-q2',
            prompt: 'When is a good time to raise contributions?',
            options: [
              'After every raise before lifestyle inflation expands',
              'Only after retirement',
              'Never',
              'Only after debt grows',
            ],
            correctIndex: 0,
            explanation:
                'Capturing raises helps grow contributions without feeling like a cut.',
          ),
        ],
      ),
      externalUrl: 'https://www.investopedia.com/retirement-planning-4689695',
      videoUrl:
          'https://www.youtube.com/results?search_query=retirement+planning+FIRE+financial+independence',
      trackId: 'advanced',
      prerequisites: ['Portfolio Construction'],
      localRelevance:
          'Adjusts retirement assumptions for PKR inflation, family support, and currency risk.',
      capstone: 'Estimate your retirement number and next contribution step.',
    ),
    LessonCourse(
      id: 'business-finance-essentials',
      title: 'Business Finance Essentials',
      subtitle: 'Manage cash flow, margins, inventory, and growth decisions',
      description:
          'A practical finance course for freelancers, shopkeepers, creators, and small business owners.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1556742502-ec7c0e9f34b1?auto=format&fit=crop&w=1200&q=80',
      category: 'Business',
      difficulty: 'Advanced',
      durationMinutes: 62,
      outcome:
          'Understand profit, cash flow, pricing, and runway before scaling.',
      pathLabel: 'Business Path',
      rating: 4.9,
      xpReward: 320,
      skillTags: ['Cash flow', 'Pricing', 'Runway'],
      lessons: [
        Lesson(
          id: 'bfe-1',
          title: 'Profit Is Not Cash',
          description: 'Separate accounting profit from money in the bank',
          content:
              'A business can be profitable and still run out of cash because inventory, receivables, and debt payments absorb money.',
          icon: 'wallet',
          points: 65,
          caseStudies: [
            'A shop has strong sales but cannot restock because too much cash is stuck in credit sales.',
          ],
          calculators: ['Cash conversion cycle worksheet'],
        ),
        Lesson(
          id: 'bfe-2',
          title: 'Pricing With Margins',
          description: 'Know your real cost before setting price',
          content:
              'Price should cover product cost, delivery, platform fees, returns, taxes, packaging, your time, and profit. Revenue alone is vanity.',
          icon: 'receipt',
          points: 70,
          templates: ['Unit economics calculator'],
        ),
        Lesson(
          id: 'bfe-3',
          title: 'Runway and Growth',
          description: 'Decide when expansion is safe',
          content:
              'Runway is how many months the business can survive at current burn. Growth should not destroy the cash buffer needed for operations.',
          icon: 'trending_up',
          points: 65,
          applicationTools: ['Runway calculator'],
        ),
      ],
      quiz: CourseQuiz(
        id: 'bfe-quiz',
        title: 'Business Finance Essentials Quiz',
        questions: [
          QuizQuestion(
            id: 'bfe-q1',
            prompt: 'Why can a profitable business still struggle?',
            options: [
              'Profit always equals cash',
              'Cash can be tied in inventory and receivables',
              'Sales never matter',
              'Margins are irrelevant',
            ],
            correctIndex: 1,
            explanation:
                'Timing matters. Cash flow can break a business before profit appears.',
          ),
          QuizQuestion(
            id: 'bfe-q2',
            prompt: 'What should pricing include?',
            options: [
              'Only product cost',
              'All costs, time, risk, and profit margin',
              'Only competitor price',
              'Only shipping',
            ],
            correctIndex: 1,
            explanation:
                'Sustainable pricing includes total cost and a fair margin.',
          ),
        ],
      ),
      externalUrl:
          'https://www.investopedia.com/articles/pf/08/small-business-finance.asp',
      videoUrl:
          'https://www.youtube.com/results?search_query=small+business+finance+cash+flow+pricing+basics',
      trackId: 'advanced',
      localRelevance:
          'Built for Pakistani freelancers, ecommerce sellers, shopkeepers, and service businesses.',
      capstone: 'Build a one-page business finance dashboard.',
    ),
    LessonCourse(
      id: 'islamic-finance-halal-investing',
      title: 'Islamic Finance and Halal Investing',
      subtitle: 'Understand riba, risk-sharing, sukuk, and screening',
      description:
          'A practical Shariah-aware introduction to Islamic finance principles and halal investing decisions.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&w=1200&q=80',
      category: 'Islamic Finance',
      difficulty: 'Specialist',
      durationMinutes: 55,
      outcome:
          'Evaluate money decisions using risk-sharing, asset-backing, and ethical screening principles.',
      pathLabel: 'Islamic Finance Path',
      rating: 4.9,
      xpReward: 300,
      skillTags: ['Riba awareness', 'Sukuk', 'Halal screening'],
      lessons: [
        Lesson(
          id: 'ifh-1',
          title: 'Riba and Risk-Sharing',
          description: 'Understand the principle before the product',
          content:
              'Islamic finance emphasizes fairness, asset-backing, risk-sharing, and avoiding prohibited income sources. Always separate principle from marketing.',
          icon: 'balance',
          points: 60,
          mythBusters: [
            'Myth: A product is halal because the label says Islamic. Reality: structure and scholar review matter.',
          ],
          applicationTools: ['Shariah review question list'],
        ),
        Lesson(
          id: 'ifh-2',
          title: 'Sukuk vs Bonds',
          description: 'Compare ownership-based certificates and debt claims',
          content:
              'Sukuk are commonly structured around ownership or usufruct in an asset, while conventional bonds are debt obligations with interest.',
          icon: 'stacked_line_chart',
          points: 65,
          keyTakeaways: [
            'Sukuk structure matters.',
            'Risk is not removed just because a product is Shariah-compliant.',
          ],
        ),
        Lesson(
          id: 'ifh-3',
          title: 'Halal Stock Screening',
          description: 'Check business activity and financial ratios',
          content:
              'Screening often reviews core business activity, interest-bearing debt, cash and receivables, and impure income. Standards can differ, so know the methodology.',
          icon: 'shield',
          points: 65,
          templates: ['Halal investment due diligence checklist'],
        ),
      ],
      quiz: CourseQuiz(
        id: 'ifh-quiz',
        title: 'Islamic Finance and Halal Investing Quiz',
        questions: [
          QuizQuestion(
            id: 'ifh-q1',
            prompt: 'What should you check beyond an Islamic label?',
            options: [
              'Product color',
              'Structure, scholar review, and underlying activity',
              'Only the advertisement',
              'Only expected return',
            ],
            correctIndex: 1,
            explanation:
                'Shariah-aware decisions require understanding structure and compliance review.',
          ),
          QuizQuestion(
            id: 'ifh-q2',
            prompt: 'What is a key halal stock screening area?',
            options: [
              'Business activity and financial ratios',
              'Logo design',
              'Only share price',
              'Only social media popularity',
            ],
            correctIndex: 0,
            explanation:
                'Screening reviews both what the company does and how it is financed.',
          ),
        ],
      ),
      externalUrl: 'https://www.investopedia.com/terms/i/islamicbanking.asp',
      videoUrl:
          'https://www.youtube.com/results?search_query=islamic+finance+halal+investing+sukuk+basics',
      trackId: 'specialist',
      prerequisites: ['Smart Investing'],
      localRelevance:
          'Designed for Pakistani Muslims comparing Islamic banking, sukuk, and halal investing choices.',
      capstone: 'Review one investment using a Shariah-aware checklist.',
    ),
    LessonCourse(
      id: 'zakat-wealth-purification',
      title: 'Zakat and Wealth Purification',
      subtitle: 'Calculate, plan, and document annual giving obligations',
      description:
          'Learn practical zakat planning for cash, gold, investments, business inventory, and liabilities.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1607863680198-23d4b2565df0?auto=format&fit=crop&w=1200&q=80',
      category: 'Islamic Finance',
      difficulty: 'Specialist',
      durationMinutes: 44,
      outcome:
          'Prepare a zakat inventory and annual reminder system with clear documentation.',
      pathLabel: 'Islamic Finance Path',
      rating: 4.8,
      xpReward: 250,
      skillTags: ['Zakat', 'Gold', 'Giving plan'],
      lessons: [
        Lesson(
          id: 'zwp-1',
          title: 'Build a Zakat Inventory',
          description: 'List cash, gold, investments, and business assets',
          content:
              'A zakat calculation begins with a clear inventory. Separate personal use assets from zakatable wealth and document values on your zakat date.',
          icon: 'wallet',
          points: 55,
          templates: ['Zakat inventory sheet'],
          localExample:
              'Record PKR bank balances, gold market value, mutual funds, receivables, and business stock where relevant.',
        ),
        Lesson(
          id: 'zwp-2',
          title: 'Liabilities and Timing',
          description: 'Understand what may reduce the base',
          content:
              'Short-term liabilities due around the zakat date may affect calculations. Because scholarly opinions can differ, keep notes and consult qualified guidance.',
          icon: 'balance',
          points: 55,
          mythBusters: [
            'Myth: Zakat planning is only for the wealthy. Reality: a simple yearly inventory helps many households.',
          ],
        ),
        Lesson(
          id: 'zwp-3',
          title: 'Giving With Intention',
          description: 'Turn obligation into a planned annual practice',
          content:
              'Set a zakat date, maintain evidence, and choose eligible recipients or organizations with care.',
          icon: 'shield',
          points: 50,
          applicationTools: ['Annual zakat reminder plan'],
        ),
      ],
      quiz: CourseQuiz(
        id: 'zwp-quiz',
        title: 'Zakat and Wealth Purification Quiz',
        questions: [
          QuizQuestion(
            id: 'zwp-q1',
            prompt: 'What is the first practical step in zakat planning?',
            options: [
              'Guessing the amount',
              'Building a wealth inventory',
              'Ignoring investments',
              'Only checking salary',
            ],
            correctIndex: 1,
            explanation:
                'A documented inventory makes the calculation more reliable.',
          ),
          QuizQuestion(
            id: 'zwp-q2',
            prompt: 'Why set a zakat date?',
            options: [
              'To avoid documentation',
              'To create consistency and annual discipline',
              'To reduce all obligations to zero',
              'To replace budgeting',
            ],
            correctIndex: 1,
            explanation:
                'A consistent date keeps records and annual planning clear.',
          ),
        ],
      ),
      externalUrl: 'https://www.islamic-relief.org/zakat/zakat-faqs/',
      videoUrl:
          'https://www.youtube.com/results?search_query=zakat+calculation+cash+gold+investments+basics',
      trackId: 'specialist',
      localRelevance:
          'Uses PKR, gold value, family obligations, business inventory, and local documentation needs.',
      capstone: 'Prepare a draft zakat inventory for your next zakat date.',
    ),
    LessonCourse(
      id: 'wealth-building-systems',
      title: 'Wealth Building Systems',
      subtitle: 'Grow net worth with income, ownership, and discipline',
      description:
          'Study the levers of long-term wealth: savings rate, income growth, ownership, taxes, risk, and behavior.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1553729459-efe14ef6055d?auto=format&fit=crop&w=1200&q=80',
      category: 'Wealth',
      difficulty: 'Advanced',
      durationMinutes: 60,
      outcome:
          'Create a personal wealth dashboard with net worth, savings rate, and next growth lever.',
      pathLabel: 'Wealth Path',
      rating: 4.9,
      xpReward: 340,
      skillTags: ['Net worth', 'Income growth', 'Ownership'],
      lessons: [
        Lesson(
          id: 'wbs-1',
          title: 'Net Worth Dashboard',
          description: 'Measure assets, liabilities, and progress',
          content:
              'Net worth is assets minus liabilities. Track it quarterly so daily market noise does not distort your long-term view.',
          icon: 'stacked_line_chart',
          points: 65,
          templates: ['Net worth tracker'],
        ),
        Lesson(
          id: 'wbs-2',
          title: 'Savings Rate Beats Vibes',
          description: 'Use one number to see wealth momentum',
          content:
              'Savings rate shows the percentage of income you keep and invest. It is one of the clearest signals of future flexibility.',
          icon: 'pie_chart',
          points: 65,
          calculators: ['Savings rate calculator'],
        ),
        Lesson(
          id: 'wbs-3',
          title: 'Own Productive Assets',
          description: 'Move from consumption to ownership',
          content:
              'Long-term wealth usually comes from owning productive assets: businesses, diversified investments, skills, and intellectual property.',
          icon: 'trending_up',
          points: 70,
          caseStudies: [
            'A salaried professional builds wealth by raising savings rate, improving skills, and investing consistently instead of chasing hot tips.',
          ],
        ),
      ],
      quiz: CourseQuiz(
        id: 'wbs-quiz',
        title: 'Wealth Building Systems Quiz',
        questions: [
          QuizQuestion(
            id: 'wbs-q1',
            prompt: 'What is net worth?',
            options: [
              'Monthly salary only',
              'Assets minus liabilities',
              'Credit card limit',
              'Annual spending',
            ],
            correctIndex: 1,
            explanation:
                'Net worth captures what you own after subtracting what you owe.',
          ),
          QuizQuestion(
            id: 'wbs-q2',
            prompt: 'Why track savings rate?',
            options: [
              'It shows how much income turns into future flexibility',
              'It guarantees no risk',
              'It replaces income growth',
              'It avoids all taxes',
            ],
            correctIndex: 0,
            explanation:
                'Savings rate connects income, spending, and wealth-building capacity.',
          ),
        ],
      ),
      externalUrl: 'https://www.investopedia.com/wealth-management-4689749',
      videoUrl:
          'https://www.youtube.com/watch?si=eJQAQCtCkAaWbLlF&v=HqdMV0mWO-8&feature=youtu.be',
      trackId: 'advanced',
      prerequisites: ['Portfolio Construction', 'Retirement and FIRE Planning'],
      localRelevance:
          'Applies wealth principles to PKR income, local inflation, family responsibilities, and career growth.',
      capstone: 'Create a quarterly wealth dashboard.',
    ),
  ];

  static IconData courseIcon(String iconName) {
    switch (iconName) {
      case 'pie_chart':
        return Icons.pie_chart_rounded;
      case 'balance':
        return Icons.balance_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'stacked_line_chart':
        return Icons.stacked_line_chart_rounded;
      case 'donut_large':
        return Icons.donut_large_rounded;
      case 'credit_score':
        return Icons.credit_score_rounded;
      case 'compare_arrows':
        return Icons.compare_arrows_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'receipt':
        return Icons.receipt_long_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'mosque':
        return Icons.mosque_rounded;
      default:
        return Icons.school_rounded;
    }
  }
}
