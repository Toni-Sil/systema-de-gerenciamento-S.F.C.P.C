// Extensão do ApiService para métodos de agenda
// Adicione estes métodos ao api_service.dart existente ou use aqui como helper

import 'api_service.dart';
import '../models/agenda_event.dart';

extension AgendaApi on ApiService {
  Future<List<AgendaEvent>> getAgendaEvents() async {
    try {
      final res = await get('/api/v1/agenda/events');
      return (res as List).map((e) => AgendaEvent.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<AgendaEvent?> createAgendaEvent(AgendaEvent event) async {
    try {
      final res = await post('/api/v1/agenda/events', body: event.toJson());
      return AgendaEvent.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteAgendaEvent(String id) async {
    try {
      await delete('/api/v1/agenda/events/$id');
      return true;
    } catch (_) {
      return false;
    }
  }
}
