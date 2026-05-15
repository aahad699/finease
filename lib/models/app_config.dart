import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfig {
  const AppConfig({
    required this.maintenanceMode,
    required this.announcementEnabled,
    required this.announcementTitle,
    required this.announcementMessage,
    required this.marketplaceEnabled,
    required this.forumEnabled,
    required this.forumPostingEnabled,
    required this.forumCommentsEnabled,
    required this.welfareEnabled,
    required this.chatbotEnabled,
    required this.budgetAiEnabled,
    required this.brandName,
    required this.brandTagline,
    required this.logoUrl,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.homeHeroTitle,
    required this.homeHeroMessage,
    required this.supportEmail,
    required this.supportMessage,
    this.updatedAt,
  });

  final bool maintenanceMode;
  final bool announcementEnabled;
  final String announcementTitle;
  final String announcementMessage;
  final bool marketplaceEnabled;
  final bool forumEnabled;
  final bool forumPostingEnabled;
  final bool forumCommentsEnabled;
  final bool welfareEnabled;
  final bool chatbotEnabled;
  final bool budgetAiEnabled;
  final String brandName;
  final String brandTagline;
  final String logoUrl;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String homeHeroTitle;
  final String homeHeroMessage;
  final String supportEmail;
  final String supportMessage;
  final DateTime? updatedAt;

  factory AppConfig.defaults() {
    return const AppConfig(
      maintenanceMode: false,
      announcementEnabled: false,
      announcementTitle: 'FinEase update',
      announcementMessage:
          'New tools and improvements are now available in FinEase.',
      marketplaceEnabled: true,
      forumEnabled: true,
      forumPostingEnabled: true,
      forumCommentsEnabled: true,
      welfareEnabled: true,
      chatbotEnabled: true,
      budgetAiEnabled: true,
      brandName: 'FinEase',
      brandTagline: 'Your finance space',
      logoUrl: '',
      primaryColorHex: '#2E3192',
      secondaryColorHex: '#00F2EA',
      homeHeroTitle: 'Financial Overview',
      homeHeroMessage:
          'Track your balance, income, and expenses in one calm view.',
      supportEmail: 'support@finease.app',
      supportMessage:
          'Some features are temporarily paused while FinEase updates the experience.',
    );
  }

  factory AppConfig.fromMap(Map<String, dynamic>? data) {
    final defaults = AppConfig.defaults();
    if (data == null) {
      return defaults;
    }

    return AppConfig(
      maintenanceMode:
          data['maintenanceMode'] as bool? ?? defaults.maintenanceMode,
      announcementEnabled:
          data['announcementEnabled'] as bool? ?? defaults.announcementEnabled,
      announcementTitle: _stringValue(
        data['announcementTitle'],
        defaults.announcementTitle,
      ),
      announcementMessage: _stringValue(
        data['announcementMessage'],
        defaults.announcementMessage,
      ),
      marketplaceEnabled:
          data['marketplaceEnabled'] as bool? ?? defaults.marketplaceEnabled,
      forumEnabled: data['forumEnabled'] as bool? ?? defaults.forumEnabled,
      forumPostingEnabled:
          data['forumPostingEnabled'] as bool? ?? defaults.forumPostingEnabled,
      forumCommentsEnabled:
          data['forumCommentsEnabled'] as bool? ??
          defaults.forumCommentsEnabled,
      welfareEnabled:
          data['welfareEnabled'] as bool? ?? defaults.welfareEnabled,
      chatbotEnabled:
          data['chatbotEnabled'] as bool? ?? defaults.chatbotEnabled,
      budgetAiEnabled:
          data['budgetAiEnabled'] as bool? ?? defaults.budgetAiEnabled,
      brandName: _stringValue(data['brandName'], defaults.brandName),
      brandTagline: _stringValue(data['brandTagline'], defaults.brandTagline),
      logoUrl: _optionalString(data['logoUrl']),
      primaryColorHex: _stringValue(
        data['primaryColorHex'],
        defaults.primaryColorHex,
      ),
      secondaryColorHex: _stringValue(
        data['secondaryColorHex'],
        defaults.secondaryColorHex,
      ),
      homeHeroTitle: _stringValue(
        data['homeHeroTitle'],
        defaults.homeHeroTitle,
      ),
      homeHeroMessage: _stringValue(
        data['homeHeroMessage'],
        defaults.homeHeroMessage,
      ),
      supportEmail: _stringValue(data['supportEmail'], defaults.supportEmail),
      supportMessage: _stringValue(
        data['supportMessage'],
        defaults.supportMessage,
      ),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maintenanceMode': maintenanceMode,
      'announcementEnabled': announcementEnabled,
      'announcementTitle': announcementTitle,
      'announcementMessage': announcementMessage,
      'marketplaceEnabled': marketplaceEnabled,
      'forumEnabled': forumEnabled,
      'forumPostingEnabled': forumPostingEnabled,
      'forumCommentsEnabled': forumCommentsEnabled,
      'welfareEnabled': welfareEnabled,
      'chatbotEnabled': chatbotEnabled,
      'budgetAiEnabled': budgetAiEnabled,
      'brandName': brandName,
      'brandTagline': brandTagline,
      'logoUrl': logoUrl,
      'primaryColorHex': primaryColorHex,
      'secondaryColorHex': secondaryColorHex,
      'homeHeroTitle': homeHeroTitle,
      'homeHeroMessage': homeHeroMessage,
      'supportEmail': supportEmail,
      'supportMessage': supportMessage,
    };
  }

  AppConfig copyWith({
    bool? maintenanceMode,
    bool? announcementEnabled,
    String? announcementTitle,
    String? announcementMessage,
    bool? marketplaceEnabled,
    bool? forumEnabled,
    bool? forumPostingEnabled,
    bool? forumCommentsEnabled,
    bool? welfareEnabled,
    bool? chatbotEnabled,
    bool? budgetAiEnabled,
    String? brandName,
    String? brandTagline,
    String? logoUrl,
    String? primaryColorHex,
    String? secondaryColorHex,
    String? homeHeroTitle,
    String? homeHeroMessage,
    String? supportEmail,
    String? supportMessage,
    DateTime? updatedAt,
  }) {
    return AppConfig(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      announcementEnabled: announcementEnabled ?? this.announcementEnabled,
      announcementTitle: announcementTitle ?? this.announcementTitle,
      announcementMessage: announcementMessage ?? this.announcementMessage,
      marketplaceEnabled: marketplaceEnabled ?? this.marketplaceEnabled,
      forumEnabled: forumEnabled ?? this.forumEnabled,
      forumPostingEnabled: forumPostingEnabled ?? this.forumPostingEnabled,
      forumCommentsEnabled: forumCommentsEnabled ?? this.forumCommentsEnabled,
      welfareEnabled: welfareEnabled ?? this.welfareEnabled,
      chatbotEnabled: chatbotEnabled ?? this.chatbotEnabled,
      budgetAiEnabled: budgetAiEnabled ?? this.budgetAiEnabled,
      brandName: brandName ?? this.brandName,
      brandTagline: brandTagline ?? this.brandTagline,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      homeHeroTitle: homeHeroTitle ?? this.homeHeroTitle,
      homeHeroMessage: homeHeroMessage ?? this.homeHeroMessage,
      supportEmail: supportEmail ?? this.supportEmail,
      supportMessage: supportMessage ?? this.supportMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _stringValue(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _optionalString(Object? value) {
    return value?.toString().trim() ?? '';
  }
}
