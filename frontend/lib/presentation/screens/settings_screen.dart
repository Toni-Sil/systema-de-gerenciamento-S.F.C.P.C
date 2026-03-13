import 'package:flutter/material.dart';
import 'package:frontend/core/providers/user_provider.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Header (Clickable)
        GestureDetector(
          onTap: () => _showEditProfile(context),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundImage: NetworkImage(userProvider.profileImageUrl),
                      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProvider.adminName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Administrador Master',
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userProvider.companyName,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Configurações da Conta',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: Theme.of(context).colorScheme.surface,
          leading: const Icon(Icons.business),
          title: const Text('Fábrica Sofa-Bed Alpha'),
          subtitle: const Text('Tenant: 4d72a43d-ecf7-4190-b3cf-35603e1dcdb6'),
          trailing: const Icon(Icons.copy, size: 16),
        ),
        const SizedBox(height: 32),
        const Text(
          'Governança de Dados (IA)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildGovernanceCard(
          context,
          'Transparência OCR',
          'Nenhum documento financeiro (NF) processado via chat é gravado em disco (LGPD). A extração usa RAM.',
          Icons.memory,
        ),
        const SizedBox(height: 12),
        _buildGovernanceCard(
          context,
          'Agente de Compras',
          'Decisões autônomas bloqueadas para movimentações > 1000 UN ou R\$ 5.000 (Human-in-the-Loop ativo).',
          Icons.pan_tool,
        ),
        const SizedBox(height: 12),
        _buildGovernanceCard(
          context,
          'Auditoria LLM',
          'Intenções são validadas por LangChain parsers. Zero risco de alucinação JSON.',
          Icons.gavel,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
            foregroundColor: Colors.redAccent,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Desconectar (Limpar JWT)', style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  void _showEditProfile(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final nameController = TextEditingController(text: userProvider.adminName);
    final companyController = TextEditingController(text: userProvider.companyName);
    String selectedAvatar = userProvider.profileImageUrl;

    final avatarPresets = [
      'https://ui-avatars.com/api/?name=Admin&background=00BCD4&color=fff',
      'https://ui-avatars.com/api/?name=Boss&background=FF9800&color=fff',
      'https://ui-avatars.com/api/?name=Manager&background=4CAF50&color=fff',
      'https://ui-avatars.com/api/?name=Owner&background=E91E63&color=fff',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Editar Perfil Profissional', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Escolha seu Avatar:', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: avatarPresets.length,
                  itemBuilder: (context, index) {
                    final avatar = avatarPresets[index];
                    final isSelected = selectedAvatar == avatar;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedAvatar = avatar),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.cyanAccent : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: NetworkImage(avatar),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController, 
                decoration: const InputDecoration(labelText: 'Seu Nome', prefixIcon: Icon(Icons.person))
              ),
              const SizedBox(height: 16),
              TextField(
                controller: companyController, 
                decoration: const InputDecoration(labelText: 'Nome da Empresa', prefixIcon: Icon(Icons.business))
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    userProvider.updateProfile(
                      nameController.text,
                      companyController.text,
                      imageUrl: selectedAvatar,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil Atualizado com Sucesso!')));
                  },
                  child: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGovernanceCard(BuildContext context, String title, String description, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
