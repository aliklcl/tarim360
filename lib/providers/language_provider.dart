import 'package:flutter_riverpod/flutter_riverpod.dart';

final languageProvider = NotifierProvider<LanguageNotifier, String>(LanguageNotifier.new);

class LanguageNotifier extends Notifier<String> {
  @override
  String build() {
    return 'tr';
  }

  Future<void> setLanguage(String lang) async {}

  bool get isEnglish => false;

  String translate(String key) {
    return _translationsTr[key] ?? key;
  }
}

// Global localization maps
const _translationsTr = {
  // Login
  'brand_title': 'Tarım360',
  'brand_subtitle': 'Ekip odaklı tarla yönetimi',
  'version_badge': 'v1.0  •  Akıllı Tarım Asistanı',
  'tab_manager': 'Yönetici Girişi',
  'tab_member': 'QR ile Katıl',
  'login': 'Giriş Yap',
  'register': 'Kayıt Ol',
  'email': 'E-posta',
  'password': 'Giriş Şifresi',
  'name_field': 'Adın (görünür isim)',
  'family_name_field': 'Ekip adı (isteğe bağlı)',
  'google_btn': 'Google ile Devam Et',
  'or': 'veya',
  'qr_desc': 'Ekibin yöneticisi sana bir QR kodu gösterecek. O kodu okutarak aynı ekibe katılabilirsin.',
  'step1_title': 'QR Kodu Okut',
  'step2_title': 'Adını Gir',
  'step3_title': 'Ekibe Katıl',
  'manager_login_desc': 'Yönetici hesabına giriş yap. Üye olarak katılmak için "QR ile Katıl" sekmesini kullan.',
  'manager_register_desc': 'Ekip yöneticisi olarak kayıt oluyorsun. Kayıt sonrasında QR kodu diğer üyelere okutarak aynı ekibe ekleyebilirsin.',

  // Home
  'today_summary': 'Bugünün Özeti',
  'total_fields': 'Toplam Tarla',
  'awaiting_watering': 'Sulama Bekleyen',
  'cloud_sync_on': 'Bulut senkronu açık',
  'local_mode': 'Yerel mod',
  'quick_actions': 'Hızlı İşlemler',
  'add_field': 'Yeni tarla ekle',
  'add_field_desc': 'Yeni tarla, konum ve sınır bilgilerini kaydet.',
  'field_summary': 'Tarla Özeti',
  'field_summary_desc': 'Toplu durum, hatırlatma ve ekip kayıtlarını gör.',
  'finance_status': 'Finansal durum',
  'finance_status_desc': 'Gelir, gider ve kar/zarar özetini görüntüle.',
  'archive': 'Arşiv',
  'archive_desc': '30 gün içinde geri yüklenebilen kayıtları yönet.',
  'fields_tab': 'Tarlalarım',

  // Profile / Settings
  'profile_info': 'Profil Bilgileri',
  'sync_now': 'Şimdi Senkronize Et',
  'edit_ops': 'İşlem Tiplerini Düzenle',
  'archive_menu': 'Arşiv (Silinen Tarlalar)',
  'appearance': 'Görünüm & Arka Plan',
  'language': 'Dil Seçeneği (Language)',
  'logout': 'Çıkış Yap',
  'version': 'Sürüm 1.0',
  'menu': 'Menü',

  // Profile Details Screen
  'membership_package': 'Üyelik Paketi',
  'name_surname': 'Ad Soyad',
  'birthday': 'Doğum Tarihi',
  'email_label': 'E-Posta',
  'phone_number': 'Telefon Numarası',
  'password_label': 'Giriş Şifresi',
  'not_added': 'Eklenmedi',
  'change': 'Değiştir',
  'add': 'Ekle',
  'save': 'Kaydet',
  'cancel': 'Vazgeç',
  
  // Password change dialog
  'change_password': 'Giriş Şifresini Değiştir',
  'old_password': 'Eski Şifre',
  'new_password': 'Yeni Şifre',
  'password_min_length': 'Şifre en az 6 karakter olmalıdır. Ekip kodu kayıt sonrası otomatik oluşturulur.',
  'password_wrong_old': 'Eski şifre hatalı.',
  'password_changed_success': 'Şifre başarıyla değiştirildi.',
  
  // Family QR
  'family_team_info': 'Aile & Ekip Bilgileri',
  'family_name': 'Ekip Adı',
  'family_access_code': 'Ekip Erişim Kodu',
  'show_qr_code': 'QR Kodu Göster',
  'invite_qr_title': 'Üye Davet QR Kodu',
  'invite_qr_desc': 'ekibine üye davet etmek için bu kodu okutun.',
  'copy_code': 'Kodu Kopyala',
  'code_copied': 'Ekip kodu panoya kopyalandı!',
  'qr_instructions': 'Üye QR Okut → İsim Gir → Katıl adımlarını takip eder.',
  'edit_family_info': 'Ekip Bilgilerini Düzenle',
  'edit_family_desc': 'Ekip adını ve kodunu değiştirebilirsin. QR paylaşılan koda göre otomatik güncellenir.',
  'update_info': 'Bilgileri Güncelle',
  'family_info_updated': 'Ekip bilgileri başarıyla güncellendi.',
  
  // Extra Home and Typos
  'operation_photos': 'İşlem Fotoğrafları',
  'no_data': 'Kayıt yok',
};

// ignore: unused_element
const _translationsEn = {
  // Login
  'brand_title': 'Tarim360',
  'brand_subtitle': 'Team-focused field management',
  'version_badge': 'v1.0  •  Smart Agri Assistant',
  'tab_manager': 'Manager Login',
  'tab_member': 'Join via QR',
  'login': 'Login',
  'register': 'Register',
  'email': 'E-mail',
  'password': 'Password',
  'name_field': 'Your Name (display name)',
  'family_name_field': 'Family Name (optional)',
  'google_btn': 'Continue with Google',
  'or': 'or',
  'qr_desc': 'Your family manager will show you a QR code. Scan that code to join the same family.',
  'step1_title': 'Scan QR Code',
  'step2_title': 'Enter Your Name',
  'step3_title': 'Join Family',
  'manager_login_desc': 'Log in to your manager account. To join as a member, use the "Join via QR" tab.',
  'manager_register_desc': 'You are registering as a family manager. After registration, scan the QR code to add other members.',

  // Home
  'today_summary': "Today's Summary",
  'total_fields': 'Total Fields',
  'awaiting_watering': 'Awaiting Watering',
  'cloud_sync_on': 'Cloud Sync Active',
  'local_mode': 'Local Mode',
  'quick_actions': 'Quick Actions',
  'add_field': 'Add New Field',
  'add_field_desc': 'Save new field, location, and border info.',
  'field_summary': 'Field Summary',
  'field_summary_desc': 'See overall status, reminders, and team logs.',
  'finance_status': 'Financial Status',
  'finance_status_desc': 'View income, expenses, and profit/loss summary.',
  'archive': 'Archive',
  'archive_desc': 'Manage records restorable within 30 days.',
  'fields_tab': 'My Fields',

  // Profile / Settings
  'profile_info': 'Profile Information',
  'sync_now': 'Sync Now',
  'edit_ops': 'Edit Operation Types',
  'archive_menu': 'Archive (Deleted Fields)',
  'appearance': 'Appearance & Background',
  'language': 'Language (Dil Seçeneği)',
  'logout': 'Log Out',
  'version': 'Version 1.0',
  'menu': 'Menu',

  // Profile Details Screen
  'membership_package': 'Membership Package',
  'name_surname': 'Name Surname',
  'birthday': 'Birthday',
  'email_label': 'E-Mail',
  'phone_number': 'Phone Number',
  'password_label': 'Password',
  'not_added': 'Not Added',
  'change': 'Change',
  'add': 'Add',
  'save': 'Save',
  'cancel': 'Cancel',
  
  // Password change dialog
  'change_password': 'Change Password',
  'old_password': 'Old Password',
  'new_password': 'New Password',
  'password_min_length': 'Password must be at least 6 characters.',
  'password_wrong_old': 'Old password is incorrect.',
  'password_changed_success': 'Password changed successfully.',
  
  // Team QR
  'family_team_info': 'Team Info',
  'family_name': 'Team Name',
  'family_access_code': 'Team Access Code',
  'show_qr_code': 'Show QR Code',
  'invite_qr_title': 'Member Invitation QR Code',
  'invite_qr_desc': 'Scan this code to join the team.',
  'copy_code': 'Copy Code',
  'code_copied': 'Team code copied to clipboard!',
  'qr_instructions': 'Member scans QR → Enters name → Joins.',
  'edit_family_info': 'Edit Team Info',
  'edit_family_desc': 'You can change the team name and code. QR code will update automatically.',
  'update_info': 'Update Info',
  'family_info_updated': 'Team info updated successfully.',
  
  // Extra Home and Typos
  'operation_photos': 'Operation Photos',
  'no_data': 'No records',
};
