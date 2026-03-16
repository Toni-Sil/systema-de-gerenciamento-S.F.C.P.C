// Model de usuário com suporte a JWT claims
class UserModel {
  final String id;
  final String name;
  final String company;
  final String role;
  final String tenantId;
  final String? profileImageUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.company,
    required this.role,
    required this.tenantId,
    this.profileImageUrl,
  });

  bool get isAdmin => role == 'admin' || role == 'owner';

  factory UserModel.fromJwtClaims(Map<String, dynamic> claims) => UserModel(
        id: claims['sub'] as String? ?? '',
        name: claims['name'] as String? ?? 'Usuário',
        company: claims['company'] as String? ?? 'S.F.C.P.C',
        role: claims['role'] as String? ?? 'operator',
        tenantId: claims['tenant_id'] as String? ?? '',
        profileImageUrl: claims['picture'] as String?,
      );

  factory UserModel.guest() => const UserModel(
        id: '',
        name: 'Convidado',
        company: 'S.F.C.P.C',
        role: 'guest',
        tenantId: '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'company': company,
        'role': role,
        'tenant_id': tenantId,
        'profile_image_url': profileImageUrl,
      };
}
