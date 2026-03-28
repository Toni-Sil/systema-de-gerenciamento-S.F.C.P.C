import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { useAlerts, useMarkAlertRead } from '@/hooks/useAlerts';
import { formatDate } from '@/lib/utils';
import { Bell, AlertTriangle, Info, AlertCircle } from 'lucide-react';

const severityIcon = {
  INFO: <Info size={16} className="text-blue-500" />,
  WARNING: <AlertTriangle size={16} className="text-yellow-500" />,
  CRITICAL: <AlertCircle size={16} className="text-red-500" />,
};

const severityVariant = {
  INFO: 'secondary' as const,
  WARNING: 'warning' as const,
  CRITICAL: 'destructive' as const,
};

export default function Alerts() {
  const { data: alerts, isLoading } = useAlerts();
  const markRead = useMarkAlertRead();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Alertas</h1>
        <p className="text-muted-foreground text-sm">Notificações do sistema</p>
      </div>
      <Card>
        <CardHeader><CardTitle className="flex items-center gap-2"><Bell size={18} /> Alertas Ativos</CardTitle></CardHeader>
        <CardContent>
          {isLoading ? (
            <p className="text-muted-foreground text-sm py-8 text-center">Carregando...</p>
          ) : !alerts?.length ? (
            <p className="text-muted-foreground text-sm py-8 text-center">Nenhum alerta. Sistema operando normalmente.</p>
          ) : (
            <div className="space-y-2">
              {alerts.map((a) => (
                <div
                  key={a.id}
                  onClick={() => !a.read && markRead.mutate(a.id)}
                  className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer transition-colors ${
                    a.read ? 'opacity-50 bg-muted/20' : 'hover:bg-accent'
                  }`}
                >
                  {severityIcon[a.severity]}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium">{a.message}</p>
                    {a.product_name && <p className="text-xs text-muted-foreground">{a.product_name}</p>}
                  </div>
                  <div className="flex flex-col items-end gap-1 shrink-0">
                    <Badge variant={severityVariant[a.severity]}>{a.severity}</Badge>
                    <span className="text-xs text-muted-foreground">{formatDate(a.created_at)}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
