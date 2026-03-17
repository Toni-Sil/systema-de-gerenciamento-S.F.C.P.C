// v2: light mode adaptativo + toggle de tema + cores via Theme.of(context)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/user_provider.dart';
import 'package:frontend/core/providers/theme_provider.dart';
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
    _apiUrlCtrl = TextEditingController(text: ApiService.instance.baseUrl);
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar'),
        content: const Text('Deseja sair e limpar o JWT desta sessao?'),
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
      await Provider.of<UserProvider>(context, listen: false).logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      }
    }
  }

  Future<void> _saveApiUrl() async {
    final url = _apiUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _savingUrl = true);
    await ApiService.instance.setBaseUrl(url);
    if (mounted) {
      setState(() => _savingUrl = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL da API salva com sucesso \u2714\uFE0F'),
          backgroundColor: AppColors.neonGreen,
        ),
      );
    }
  }

  void _showEditProfile(BuildContext context) {
    final up = Provider.of<UserProvider>(context, listen: false);
    final nameCtrl = TextEditingController(text: up.adminName);
    final companyCtrl = TextEditingController(text: up.companyName);
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Editar Perfil',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurface)),
              const SizedBox(height: 20),
              Text('Avatar:',
                  style: TextStyle(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontSize: 13)),
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
                      onTap: () => setSheet(() => selectedAvatar = av),
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 8),
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
                            content: Text('Perfil atualizado \u2714\uFE0F'),
                            backgroundColor: AppColors.neonGreen),
                      );
                    }
                  },
                  child: const Text('Salvar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final up = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final cs = Theme.of(context).colorScheme;
    final cardColor = isDark ? AppColors.bgCard : AppColors.lgBgCard;
    final borderColor = isDark ? AppColors.border : AppColors.lgBorder;
    final surfaceColor = isDark ? AppColors.bgSurface : AppColors.lgBgSurface;
    final textHigh = isDark ? AppColors.textHigh : AppColors.lgTextHigh;
    final textLow = isDark ? AppColors.textLow : AppColors.lgTextLow;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ─ Card de Perfil
        GestureDetector(
          onTap: () => _showEditProfile(context),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.neonCyan.withValues(alpha: isDark ? 0.12 : 0.08),
                  AppColors.neonPurple.withValues(alpha: isDark ? 0.08 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.neonCyan.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundImage: NetworkImage(up.profileImageUrl),
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
                            size: 11, color: AppColors.bgDeep),
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
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textHigh)),
                      const SizedBox(height: 2),
                      Text(
                        up.role == 'admin' || up.role == 'owner'
                            ? 'Administrador Master'
                            : 'Operador',
                        style: const TextStyle(
                            color: AppColors.neonCyan,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(up.companyName,
                          style: TextStyle(fontSize: 13, color: textLow)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: textLow),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ─ Aparencia
        _sectionTitle('Aparencia', textHigh),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: AppColors.neonCyan,
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isDark ? 'Modo Escuro' : 'Modo Claro',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textHigh),
                ),
              ),
              Switch.adaptive(
                value: isDark,
                activeColor: AppColors.neonCyan,
                onChanged: (_) => themeProvider.toggle(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ─ Configuracoes da Conta
        _sectionTitle('Configuracoes da Conta', textHigh),
        const SizedBox(height: 12),

        // Tenant ID
        _infoTile(
          Icons.business,
          up.companyName,
          'Tenant: ${up.tenantId.isEmpty ? 'nao autenticado' : up.tenantId}',
          cardColor: cardColor,
          borderColor: borderColor,
          textHigh: textHigh,
          textLow: textLow,
          trailingWidget: up.tenantId.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.copy, size: 16, color: textLow),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: up.tenantId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tenant ID copiado')),
                    );
                  },
                )
              : null,
        ),

        const SizedBox(height: 10),

        // URL da API
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.api, color: AppColors.neonAmber, size: 18),
                  const SizedBox(width: 10),
                  Text('URL do Servidor API',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textHigh)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiUrlCtrl,
                keyboardType: TextInputType.url,
                style: TextStyle(fontSize: 13, color: textHigh),
                decoration: InputDecoration(
                  hintText: 'http://seu-servidor:8000',
                  fillColor: surfaceColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
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
                              strokeWidth: 2, color: AppColors.bgDeep))
                      : const Text('Salvar URL',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ─ Governanca de Dados
        _sectionTitle('Governanca de Dados (IA)', textHigh),
        const SizedBox(height: 12),
        _govCard(
          'Transparencia OCR',
          'Nenhum documento financeiro processado via chat e gravado em disco (LGPD). A extracao usa RAM.',
          Icons.memory,
          AppColors.neonCyan,
          cardColor: cardColor,
          borderColor: borderColor,
          textHigh: textHigh,
          textLow: textLow,
        ),
        const SizedBox(height: 10),
        _govCard(
          'Agente de Compras',
          'Decisoes autonomas bloqueadas para movimentacoes > 1000 UN ou R\$ 5.000 (Human-in-the-Loop ativo).',
          Icons.pan_tool,
          AppColors.neonAmber,
          cardColor: cardColor,
          borderColor: borderColor,
          textHigh: textHigh,
          textLow: textLow,
        ),
        const SizedBox(height: 10),
        _govCard(
          'Auditoria LLM',
          'Intencoes validadas por parsers estruturados. Zero risco de alucinacao JSON.',
          Icons.gavel,
          AppColors.neonPurple,
          cardColor: cardColor,
          borderColor: borderColor,
          textHigh: textHigh,
          textLow: textLow,
        ),

        const SizedBox(height: 32),

        // ─ Logout
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

  Widget _sectionTitle(String t, Color color) =>
      Text(t,
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: color));

  Widget _infoTile(
    IconData icon,
    String title,
    String subtitle, {
    required Color cardColor,
    required Color borderColor,
    required Color textHigh,
    required Color textLow,
    Widget? trailingWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: textLow),
        title: Text(title, style: TextStyle(color: textHigh)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 11, color: textLow)),
        trailing: trailingWidget,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _govCard(
    String title,
    String desc,
    IconData icon,
    Color color, {
    required Color cardColor,
    required Color borderColor,
    required Color textHigh,
    required Color textLow,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textHigh)),
                const SizedBox(height: 4),
                Text(desc,
                    style: TextStyle(
                        color: textLow, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
