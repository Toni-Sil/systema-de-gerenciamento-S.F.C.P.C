import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/agenda_event.dart';
import '../../core/providers/agenda_provider.dart';
import '../../core/services/voice_agent_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/uid.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/flat_card.dart';

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
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDailySummarySnackbar();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _showDailySummarySnackbar() {
    final messenger = ScaffoldMessenger.of(context);
    final agenda = context.read<AgendaProvider>();
    if (agenda.todayCount > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Você tem ${agenda.todayCount} evento(s) hoje'
            '${agenda.urgentCount > 0 ? ' — ${agenda.urgentCount} urgente(s)!' : '.'}',
          ),
          backgroundColor: AppColors.neonCyan.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _startVoiceListening() async {
    final voice = VoiceAgentService.instance;
    final ok = await voice.init();
    if (!ok) {
      if (mounted) _showError('Microfone não disponível. Verifique a permissão.');
      return;
    }
    if (mounted) {
      setState(() {
        _isListening = true;
        _voicePartial = 'Ouvindo...';
      });
    }
    _pulseCtrl.repeat(reverse: true);

    final result = await voice.listen(
      onPartial: (partial) {
        if (mounted && partial.isNotEmpty) setState(() => _voicePartial = partial);
      },
    );

    _pulseCtrl.stop();
    _pulseCtrl.reset();
    if (mounted) setState(() { _isListening = false; _voicePartial = ''; });
    if (!mounted) return;

    if (result != null && result.isNotEmpty) {
      final agenda = context.read<AgendaProvider>();
      final response = await agenda.processVoiceCommand(result);
      if (mounted) _showSuccess(response);
    }
  }

  Future<void> _stopVoiceListening() async {
    await VoiceAgentService.instance.stop();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    if (mounted) setState(() { _isListening = false; _voicePartial = ''; });
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.neonGreen.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
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
            const Text('Agenda',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHigh)),
            Text('${agenda.todayCount} evento(s) hoje',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textLow)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textLow),
            onPressed: () => NotificationService.instance
                .showDailySummary(agenda.todaySummaryForAgent),
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

  Widget _buildWeekStrip(AgendaProvider agenda) {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: days.map((day) {
          final isSelected = day.year == agenda.selectedDay.year &&
              day.month == agenda.selectedDay.month &&
              day.day == agenda.selectedDay.day;
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;
          final hasEvents = agenda.events.any((e) =>
              e.dateTime.year == day.year &&
              e.dateTime.month == day.month &&
              e.dateTime.day == day.day &&
              e.status != EventStatus.cancelado);
          return Expanded(
            child: GestureDetector(
              onTap: () => agenda.setSelectedDay(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.neonCyan.withValues(alpha: 0.15)
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
                      const ['Seg','Ter','Qua','Qui','Sex','Sáb','Dom']
                          [day.weekday - 1],
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? AppColors.neonCyan
                            : AppColors.textLow,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${day.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.neonCyan
                              : AppColors.textHigh,
                        )),
                    if (hasEvents)
                      Container(
                        width: 4, height: 4,
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
    if (agenda.todayCount == 0) return const SizedBox.shrink();
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
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMed),
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
            Icon(Icons.event_available,
                size: 56,
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

  // FIX #4: usa FlatCard (sem BackdropFilter) nos cards de lista
  Widget _buildEventCard(AgendaEvent event, AgendaProvider agenda) {
    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: const Text('Excluir evento?',
                style: TextStyle(color: AppColors.textHigh)),
            content: Text('"${event.title}" será removido.',
                style: const TextStyle(color: AppColors.textMed)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Excluir',
                      style: TextStyle(color: AppColors.neonRed))),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => agenda.deleteEvent(event.id),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        // FIX #4: FlatCard em vez de GlassCard
        child: FlatCard(
          onTap: () => _showEventDetail(context, event, agenda),
          borderColor: event.priorityColor.withValues(alpha: 0.5),
          child: Row(
            children: [
              Container(
                width: 4, height: 50,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: event.priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.formattedTime,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textHigh)),
                  if (event.duration != null)
                    Text('${event.duration!.inMinutes}min',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textLow)),
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
                              decoration:
                                  event.status == EventStatus.concluido
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
                      Text(event.description!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textLow),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (event.location != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11, color: AppColors.textLow),
                        const SizedBox(width: 3),
                        Text(event.location!,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textLow)),
                      ]),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  if (event.isVoiceCreated)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Icon(Icons.mic,
                          size: 12, color: AppColors.neonCyan),
                    ),
                  if (event.status != EventStatus.concluido)
                    GestureDetector(
                      onTap: () => agenda.markCompleted(event.id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              AppColors.neonGreen.withValues(alpha: 0.15),
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isListening && _voicePartial.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.neonCyan.withValues(alpha: 0.4)),
            ),
            child: Text(_voicePartial,
                style: const TextStyle(
                    color: AppColors.textHigh, fontSize: 13)),
          ),
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: _isListening ? _pulseAnim.value : 1.0,
            child: child,
          ),
          child: FloatingActionButton.extended(
            onPressed:
                _isListening ? _stopVoiceListening : _startVoiceListening,
            backgroundColor:
                _isListening ? AppColors.neonRed : AppColors.neonCyan,
            foregroundColor: AppColors.bgDeep,
            icon: Icon(_isListening ? Icons.stop : Icons.mic_none),
            label: Text(_isListening ? 'Parar' : 'Agendar por voz'),
          ),
        ),
      ],
    );
  }

  // FIX #5: usa Uid.generate() e ctx local capturado do StatefulBuilder
  void _showAddEventDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final localCtrl = TextEditingController();
    // Captura provider antes de abrir o sheet — safe mesmo se tela desmontar
    final agendaProvider = context.read<AgendaProvider>();
    final initialDay = agendaProvider.selectedDay;
    DateTime selectedDate = initialDay;
    TimeOfDay selectedTime = TimeOfDay.now();
    EventCategory category = EventCategory.outro;
    EventPriority priority = EventPriority.normal;
    int notifyMin = 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              left: 20, right: 20, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Novo Evento',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHigh)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textLow),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Título *'),
                  style: const TextStyle(color: AppColors.textHigh),
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Descrição'),
                  style: const TextStyle(color: AppColors.textHigh),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: localCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Local',
                      prefixIcon: Icon(Icons.location_on_outlined)),
                  style: const TextStyle(color: AppColors.textHigh),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: sheetCtx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (d != null) setS(() => selectedDate = d);
                        },
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text(
                            '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: sheetCtx,
                              initialTime: selectedTime);
                          if (t != null) setS(() => selectedTime = t);
                        },
                        icon:
                            const Icon(Icons.access_time, size: 14),
                        label: Text(selectedTime.format(sheetCtx)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Categoria',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textLow)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: EventCategory.values.map((c) {
                    const labels = {
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
                const Text('Prioridade',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textLow)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: EventPriority.values.map((p) {
                    const names = {
                      EventPriority.baixa: 'Baixa',
                      EventPriority.normal: 'Normal',
                      EventPriority.alta: 'Alta',
                      EventPriority.urgente: 'Urgente',
                    };
                    return ChoiceChip(
                      label: Text(names[p]!),
                      selected: priority == p,
                      onSelected: (_) => setS(() => priority = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Notificar',
                        style: TextStyle(color: AppColors.textMed)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: notifyMin,
                      dropdownColor: AppColors.bgCard,
                      style: const TextStyle(
                          color: AppColors.textHigh),
                      items: [10, 15, 30, 60, 120].map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(m < 60
                              ? '${m}min antes'
                              : '${m ~/ 60}h antes'),
                        );
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
                      final t = titleCtrl.text.trim();
                      if (t.isEmpty) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Digite um título para o evento.')),
                        );
                        return;
                      }
                      final dt = DateTime(
                        selectedDate.year, selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour, selectedTime.minute,
                      );
                      // FIX #5: usa agendaProvider capturado antes do sheet
                      // FIX #7: usa Uid.generate() para ID único
                      agendaProvider.addEvent(AgendaEvent(
                        id: Uid.generate(),
                        title: t,
                        description: descCtrl.text.trim().isNotEmpty
                            ? descCtrl.text.trim()
                            : null,
                        location: localCtrl.text.trim().isNotEmpty
                            ? localCtrl.text.trim()
                            : null,
                        dateTime: dt,
                        category: category,
                        priority: priority,
                        notifyBefore: true,
                        notifyMinutes: notifyMin,
                      ));
                      Navigator.pop(sheetCtx);
                      _showSuccess('Evento criado com sucesso!');
                    },
                    child: const Text('Salvar Evento'),
                  ),
                ),
                const SizedBox(height: 28),
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(event.categoryIcon,
                    color: event.priorityColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(event.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHigh)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: event.priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    event.priority.name[0].toUpperCase() +
                        event.priority.name.substring(1),
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
              _detailRow(
                  Icons.location_on_outlined, event.location!),
            if (event.description != null)
              _detailRow(Icons.notes, event.description!),
            _detailRow(Icons.notifications_outlined,
                'Lembrete ${event.notifyMinutes}min antes'),
            if (event.isVoiceCreated)
              _detailRow(Icons.mic, 'Criado por voz'),
            const SizedBox(height: 20),
            Row(
              children: [
                if (event.status != EventStatus.concluido) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        agenda.markCompleted(event.id);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Concluído'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonGreen,
                          foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      agenda.deleteEvent(event.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.neonRed),
                    label: const Text('Excluir',
                        style:
                            TextStyle(color: AppColors.neonRed)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.neonRed)),
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
