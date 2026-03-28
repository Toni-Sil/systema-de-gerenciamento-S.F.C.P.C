import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useProducts } from '@/hooks/useStock';
import { formatCurrency } from '@/lib/utils';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

export default function StockBalance() {
  const { data: products, isLoading } = useProducts();

  const chartData = products?.slice(0, 10).map((p) => ({
    name: p.name.length > 12 ? p.name.slice(0, 12) + '…' : p.name,
    quantidade: p.quantity,
    minimo: p.min_quantity,
  })) ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Balanço de Estoque</h1>
        <p className="text-muted-foreground text-sm">Quantidade atual vs mínimo por produto</p>
      </div>
      <Card>
        <CardHeader><CardTitle>Top 10 Produtos — Quantidade</CardTitle></CardHeader>
        <CardContent>
          {isLoading ? (
            <p className="text-muted-foreground text-sm py-8 text-center">Carregando...</p>
          ) : (
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
                <XAxis dataKey="name" className="text-xs" />
                <YAxis className="text-xs" />
                <Tooltip />
                <Bar dataKey="quantidade" fill="#6366f1" radius={[4, 4, 0, 0]} />
                <Bar dataKey="minimo" fill="#f43f5e" radius={[4, 4, 0, 0]} opacity={0.5} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </CardContent>
      </Card>
      <Card>
        <CardHeader><CardTitle>Valor por Produto</CardTitle></CardHeader>
        <CardContent>
          <div className="space-y-2">
            {(products ?? []).map((p) => (
              <div key={p.id} className="flex justify-between items-center py-2 border-b last:border-0">
                <span className="text-sm">{p.name}</span>
                <span className="text-sm font-medium">{formatCurrency(p.quantity * p.unit_cost)}</span>
              </div>
            ))}
            {!products?.length && <p className="text-muted-foreground text-sm py-4 text-center">Sem dados. Backend desconectado.</p>}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
