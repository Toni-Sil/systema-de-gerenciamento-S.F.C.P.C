import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/agenda_event.dart';
import '../../core/providers/agenda_provider.dart';
import '../../core/services/voice_agent_service.dart';
import '../../core/services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _voicePartial = '';
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // Mostra resumo do dia ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDailySummarySnackbar();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _showDailySummarySnackbar() {
    final agenda = context.read<AgendaProvider>();
    if (agenda.todayCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Você tem ${agenda.todayCount} evento(s) hoje. '
              '${agenda.urgentCount > 0 ? '${agenda.urgentCount} urgente(s)!' : ''}'),
          backgroundColor: AppColors.neonCyan.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _startVoiceListening() async {
    final agenda = context.read<AgendaProvider>();
    final voice = VoiceAgentService.instance;

    final ok = await voice.init();
    if (!ok) {
      _showError('Microfone não disponível.');
      return;
    }

    setState(() {
      _isListening = true;
      _voicePartial = 'Ouvindo...';
    });
    _pulseCtrl.repeat(reverse: true);

    final result = await voice.listen(
      onPartial: (partial) {
        if (mounted) setState(() => _voicePartial = partial);
      },
    );

    _pulseCtrl.stop();
    setState(() => _isListening = false);

    if (result != null && result.isNotEmpty) {
      final response = await agenda.processVoiceCommand(result);
      _showSuccess(response);
    } else {
      setState(() => _voicePartial = '');
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.neonGreen.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.neonRed.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final agenda = context.watch<AgendaProvider>();
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agenda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
            Text(
              '${agenda.todayCount} evento(s) hoje',
              style: const TextStyle(fontSize: 11, color: AppColors.textLow),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textLow),
            onPressed: () {
              NotificationService.instance.showDailySummary(
                  agenda.todaySummaryForAgent);
            },
            tooltip: 'Resumo do dia',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.neonCyan),
            onPressed: () => _showAddEventDialog(context),
            tooltip: 'Novo evento',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekStrip(agenda),
          _buildTodaySummaryCard(agenda),
          Expanded(child: _buildEventList(agenda)),
        ],
      ),
      floatingActionButton: _buildVoiceFab(),
    );
  }

  // Faixa de dias da semana
  Widget _buildWeekStrip(AgendaProvider agenda) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: today.weekday - 1 - i)));
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: days.map((day) {
          final isSelected = day.day == agenda.selectedDay.day &&
              day.month == agenda.selectedDay.month;
          final isToday = day.day == today.day && day.month == today.month;
          final hasEvents = agenda.events.any((e) =>
              e.dateTime.day == day.day && e.dateTime.month == day.month);
          return Expanded(
            child: GestureDetector(
              onTap: () => agenda.setSelectedDay(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.neonCyan.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.neonCyan
                        : isToday
                            ? AppColors.neonCyan.withValues(alpha: 0.4)
                            : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']
                          [day.weekday - 1],
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? AppColors.neonCyan : AppColors.textLow,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.neonCyan : AppColors.textHigh,
                      ),
                    ),
                    if (hasEvents)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: const BoxDecoration(
                          color: AppColors.neonCyan,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 7),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTodaySummaryCard(AgendaProvider agenda) {
    if (agenda.todayCount == 0) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        gradientColors: const [AppColors.neonCyan, AppColors.neonPurple],
        child: Row(
          children: [
            const Icon(Icons.today, color: AppColors.neonCyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                agenda.todaySummaryForAgent,
                style: const TextStyle(fontSize: 12, color: AppColors.textMed),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(AgendaProvider agenda) {
    final events = agenda.selectedDayEvents;
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 56,
                color: AppColors.textLow.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('Nenhum evento neste dia',
                style: TextStyle(color: AppColors.textLow)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showAddEventDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar evento'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: events.length,
      itemBuilder: (_, i) => _buildEventCard(events[i], agenda),
    );
  }

  Widget _buildEventCard(AgendaEvent event, AgendaProvider agenda) {
    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.neonRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.neonRed),
      ),
      onDismissed: (_) => agenda.deleteEvent(event.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          onTap: () => _showEventDetail(context, event, agenda),
          borderColor: event.priorityColor.withValues(alpha: 0.5),
          child: Row(
            children: [
              // Linha de cor da prioridade
              Container(
                width: 4,
                height: 50,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: event.priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Hora
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.formattedTime,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHigh),
                  ),
                  if (event.duration != null)
                    Text(
                      '${event.duration!.inMinutes}min',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textLow),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(event.categoryIcon,
                            size: 14, color: AppColors.textLow),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: event.status == EventStatus.concluido
                                  ? AppColors.textLow
                                  : AppColors.textHigh,
                              decoration: event.status == EventStatus.concluido
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (event.description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        event.description!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textLow),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (event.location != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: AppColors.textLow),
                          const SizedBox(width: 3),
                          Text(event.location!,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textLow)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Ações rápidas
              Column(
                children: [
                  if (event.isVoiceCreated)
                    const Icon(Icons.mic, size: 12, color: AppColors.neonCyan),
                  const SizedBox(height: 6),
                  if (event.status != EventStatus.concluido)
                    GestureDetector(
                      onTap: () => agenda.markCompleted(event.id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.neonGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 14, color: AppColors.neonGreen),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isListening && _voicePartial.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.4)),
            ),
            child: Text(
              _voicePartial,
              style: const TextStyle(color: AppColors.textHigh, fontSize: 13),
            ),
          ),
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: _isListening ? _pulseAnim.value : 1.0,
            child: child,
          ),
          child: FloatingActionButton.extended(
            onPressed: _isListening ? null : _startVoiceListening,
            backgroundColor:
                _isListening ? AppColors.neonRed : AppColors.neonCyan,
            foregroundColor: AppColors.bgDeep,
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            label: Text(_isListening ? 'Ouvindo...' : 'Agendar por voz'),
          ),
        ),
      ],
    );
  }

  void _showAddEventDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final localCtrl = TextEditingController();
    DateTime selectedDate = context.read<AgendaProvider>().selectedDay;
    TimeOfDay selectedTime = TimeOfDay.now();
    EventCategory category = EventCategory.outro;
    EventPriority priority = EventPriority.normal;
    int notifyMin = 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Novo Evento',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHigh)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  style: const TextStyle(color: AppColors.textHigh),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Descrição'),
                  style: const TextStyle(color: AppColors.textHigh),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: localCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Local', prefixIcon: Icon(Icons.location_on_outlined)),
                  style: const TextStyle(color: AppColors.textHigh),
                ),
                const SizedBox(height: 16),
                // Data e hora
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (d != null) setS(() => selectedDate = d);
                        },
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: ctx, initialTime: selectedTime);
                          if (t != null) setS(() => selectedTime = t);
                        },
                        icon: const Icon(Icons.access_time, size: 14),
                        label: Text(selectedTime.format(ctx)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Categoria
                const Text('Categoria',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textLow)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: EventCategory.values.map((c) {
                    final labels = {
                      EventCategory.reuniao: 'Reunião',
                      EventCategory.entrega: 'Entrega',
                      EventCategory.reposicao: 'Reposição',
                      EventCategory.financeiro: 'Financeiro',
                      EventCategory.pessoal: 'Pessoal',
                      EventCategory.outro: 'Outro',
                    };
                    return ChoiceChip(
                      label: Text(labels[c]!),
                      selected: category == c,
                      onSelected: (_) => setS(() => category = c),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Prioridade
                const Text('Prioridade',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textLow)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: EventPriority.values.map((p) {
                    return ChoiceChip(
                      label: Text(p.name),
                      selected: priority == p,
                      onSelected: (_) => setS(() => priority = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Notificar antes
                Row(
                  children: [
                    const Text('Notificar',
                        style: TextStyle(color: AppColors.textMed)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: notifyMin,
                      dropdownColor: AppColors.bgCard,
                      style:
                          const TextStyle(color: AppColors.textHigh),
                      items: [10, 15, 30, 60, 120].map((m) {
                        return DropdownMenuItem(
                            value: m,
                            child: Text(
                                m < 60 ? '${m}min antes' : '${m ~/ 60}h antes'));
                      }).toList(),
                      onChanged: (v) =>
                          setS(() => notifyMin = v ?? 30),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.isEmpty) return;
                      final dt = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      context.read<AgendaProvider>().addEvent(AgendaEvent(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            title: titleCtrl.text,
                            description: descCtrl.text.isNotEmpty
                                ? descCtrl.text
                                : null,
                            location: localCtrl.text.isNotEmpty
                                ? localCtrl.text
                                : null,
                            dateTime: dt,
                            category: category,
                            priority: priority,
                            notifyBefore: true,
                            notifyMinutes: notifyMin,
                          ));
                      Navigator.pop(ctx);
                      _showSuccess('Evento criado com sucesso!');
                    },
                    child: const Text('Salvar Evento'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDetail(
      BuildContext context, AgendaEvent event, AgendaProvider agenda) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(event.categoryIcon, color: event.priorityColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHigh),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: event.priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    event.priority.name,
                    style: TextStyle(
                        fontSize: 11,
                        color: event.priorityColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.calendar_today,
                '${event.formattedDate} às ${event.formattedTime}'),
            if (event.duration != null)
              _detailRow(Icons.timer_outlined,
                  'Duração: ${event.duration!.inMinutes} minutos'),
            if (event.location != null)
              _detailRow(Icons.location_on_outlined, event.location!),
            if (event.description != null)
              _detailRow(Icons.notes, event.description!),
            _detailRow(Icons.notifications_outlined,
                'Lembrete ${event.notifyMinutes}min antes'),
            if (event.isVoiceCreated)
              _detailRow(Icons.mic, 'Criado por voz'),
            const SizedBox(height: 20),
            Row(
              children: [
                if (event.status != EventStatus.concluido)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        agenda.markCompleted(event.id);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Concluído'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonGreen),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      agenda.deleteEvent(event.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.neonRed),
                    label: const Text('Excluir',
                        style: TextStyle(color: AppColors.neonRed)),
                    style: OutlinedButton.styleFrom(
                        side:
                            const BorderSide(color: AppColors.neonRed)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textLow),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMed))),
        ],
      ),
    );
  }
}
