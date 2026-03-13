// PR-D — SettingsScreen: logout real, URL da API configurável, tenantId dinâmico, role do JWT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/user_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/presentation/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiUrlCtrl;
  bool _savingUrl = false;

  @override
  void initState() {
    super.initState();
    _apiUrlCtrl =
        TextEditingController(text: ApiService.instance.baseUrl);
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    super.dispose();
  }

  // ─── Logout real ───────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar'),
        content:
            const Text('Deseja sair e limpar o JWT desta sessão?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonRed,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sair')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await Provider.of<UserProvider>(context, listen: false)
          .logout();
      // Volta para OnboardingScreen / LoginScreen
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (_) => false);
      }
    }
  }

  // ─── Salvar URL da API ───────────────────────────────────────────────────

  Future<void> _saveApiUrl() async {
    final url = _apiUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _savingUrl = true);
    await ApiService.instance.setBaseUrl(url);
    if (mounted) {
      setState(() => _savingUrl = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL da API salva com sucesso ✔️'),
          backgroundColor: AppColors.neonGreen,
        ),
      );
    }
  }

  // ─── Edit Profile ──────────────────────────────────────────────────────────

  void _showEditProfile(BuildContext context) {
    final up =
        Provider.of<UserProvider>(context, listen: false);
    final nameCtrl =
        TextEditingController(text: up.adminName);
    final companyCtrl =
        TextEditingController(text: up.companyName);
    String selectedAvatar = up.profileImageUrl;

    final avatarPresets = [
      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(up.adminName)}&background=00BCD4&color=fff',
      'https://ui-avatars.com/api/?name=Boss&background=FF9800&color=fff',
      'https://ui-avatars.com/api/?name=Manager&background=4CAF50&color=fff',
      'https://ui-avatars.com/api/?name=Owner&background=E91E63&color=fff',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Editar Perfil',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHigh)),
              const SizedBox(height: 20),
              // Avatares preset
              const Text('Avatar:',
                  style: TextStyle(
                      color: AppColors.textLow, fontSize: 13)),
              const SizedBox(height: 10),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: avatarPresets.length,
                  itemBuilder: (_, i) {
                    final av = avatarPresets[i];
                    final sel = selectedAvatar == av;
                    return GestureDetector(
                      onTap: () =>
                          setSheet(() => selectedAvatar = av),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel
                                ? AppColors.neonCyan
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: NetworkImage(av),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Seu Nome',
                    prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nome da Empresa',
                    prefixIcon: Icon(Icons.business)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.neonCyan,
                    foregroundColor: AppColors.bgDeep,
                  ),
                  onPressed: () async {
                    await up.updateProfile(
                      nameCtrl.text,
                      companyCtrl.text,
                      imageUrl: selectedAvatar,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Perfil atualizado ✔️'),
                          backgroundColor: AppColors.neonGreen,
                        ),
                      );
                    }
                  },
                  child: const Text('Salvar',
                      style: TextStyle(
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final up = Provider.of<UserProvider>(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // ─ Perfil
        GestureDetector(
          onTap: () => _showEditProfile(context),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.neonCyan.withValues(alpha: 0.12),
                  AppColors.neonPurple.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.neonCyan
                      .withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundImage:
                          NetworkImage(up.profileImageUrl),
                      backgroundColor:
                          AppColors.neonCyan.withValues(alpha: 0.1),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.neonCyan,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            size: 11,
                            color: AppColors.bgDeep),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(up.adminName,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHigh)),
                      const SizedBox(height: 2),
                      // Role dinâmica do JWT
                      Text(
                        up.role == 'admin' || up.role == 'owner'
                            ? 'Administrador Master'
                            : 'Operador',
                        style: TextStyle(
                            color: AppColors.neonCyan,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(up.companyName,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textLow)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textLow),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ─ Configurações da Conta
        _sectionTitle('Configurações da Conta'),
        const SizedBox(height: 12),

        // Tenant ID — dinâmico do JWT
        _infoTile(
          Icons.business,
          up.companyName,
          'Tenant: ${up.tenantId.isEmpty ? 'não autenticado' : up.tenantId}',
          trailingWidget: up.tenantId.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.copy,
                      size: 16, color: AppColors.textLow),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: up.tenantId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Tenant ID copiado')),
                    );
                  },
                )
              : null,
        ),

        const SizedBox(height: 10),

        // URL da API configurável
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.api, color: AppColors.neonAmber, size: 18),
                  SizedBox(width: 10),
                  Text('URL do Servidor API',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHigh)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiUrlCtrl,
                keyboardType: TextInputType.url,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textHigh),
                decoration: InputDecoration(
                  hintText: 'http://seu-servidor:8000',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: AppColors.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonAmber,
                    foregroundColor: AppColors.bgDeep,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _savingUrl ? null : _saveApiUrl,
                  child: _savingUrl
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bgDeep))
                      : const Text('Salvar URL',
                          style: TextStyle(
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ─ Governança de Dados (IA)
        _sectionTitle('Governança de Dados (IA)'),
        const SizedBox(height: 12),
        _govCard(
          'Transparência OCR',
          'Nenhum documento financeiro (NF) processado via chat é gravado em disco (LGPD). A extração usa RAM.',
          Icons.memory,
          AppColors.neonCyan,
        ),
        const SizedBox(height: 10),
        _govCard(
          'Agente de Compras',
          'Decisões autônomas bloqueadas para movimentações > 1000 UN ou R\$ 5.000 (Human-in-the-Loop ativo).',
          Icons.pan_tool,
          AppColors.neonAmber,
        ),
        const SizedBox(height: 10),
        _govCard(
          'Auditoria LLM',
          'Intenções validadas por parsers estruturados. Zero risco de alucinação JSON.',
          Icons.gavel,
          AppColors.neonPurple,
        ),

        const SizedBox(height: 32),

        // ─ Botão Logout real
        ElevatedButton.icon(
          onPressed: _logout,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonRed.withValues(alpha: 0.15),
            foregroundColor: AppColors.neonRed,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            side: BorderSide(
                color: AppColors.neonRed.withValues(alpha: 0.4)),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Desconectar (Limpar JWT)',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppColors.textHigh));

  Widget _infoTile(IconData icon, String title, String subtitle,
      {Widget? trailingWidget}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textLow),
        title: Text(title,
            style: const TextStyle(color: AppColors.textHigh)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textLow)),
        trailing: trailingWidget,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _govCard(
      String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textHigh)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        color: AppColors.textLow,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
