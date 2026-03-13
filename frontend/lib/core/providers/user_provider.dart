import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  String _adminName = 'Toni-Sil';
  String _companyName = 'S.F.C.P.C';
  String _profileImageUrl = 'https://ui-avatars.com/api/?name=Admin&background=00BCD4&color=fff';

  String get adminName => _adminName;
  String get companyName => _companyName;
  String get profileImageUrl => _profileImageUrl;

  void updateProfile(String name, String company, {String? imageUrl}) {
    _adminName = name;
    _companyName = company;
    if (imageUrl != null) {
      _profileImageUrl = imageUrl;
    }
    notifyListeners();
  }
}
