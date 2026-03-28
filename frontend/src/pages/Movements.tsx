import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { useMovements } from '@/hooks/useStock';
import { formatDate } from '@/lib/utils';
import { ArrowDownCircle, ArrowUpCircle } from 'lucide-react';

export default function Movements() {
  const { data: movements, isLoading } = useMovements(100);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Movimentações</h1>
        <p className="text-muted-foreground text-sm">Entradas e saídas de estoque</p>
      </div>
      <Card>
        <CardHeader><CardTitle>Histórico</CardTitle></CardHeader>
        <CardContent>
          {isLoading ? (
            <p className="text-muted-foreground text-sm py-8 text-center">Carregando...</p>
          ) : !movements?.length ? (
            <p className="text-muted-foreground text-sm py-8 text-center">Sem movimentações. Backend desconectado.</p>
          ) : (
            <div className="space-y-2">
              {movements.map((m) => (
                <div key={m.id} className="flex items-center gap-3 py-3 border-b last:border-0">
                  {m.type === 'IN'
                    ? <ArrowDownCircle size={20} className="text-green-500 shrink-0" />
                    : <ArrowUpCircle size={20} className="text-red-500 shrink-0" />}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">{m.product_name}</p>
                    <p className="text-xs text-muted-foreground">{m.note ?? ''}</p>
                  </div>
                  <Badge variant={m.type === 'IN' ? 'success' : 'destructive'}>
                    {m.type === 'IN' ? '+' : '-'}{m.quantity}
                  </Badge>
                  <span className="text-xs text-muted-foreground shrink-0">{formatDate(m.created_at)}</span>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
