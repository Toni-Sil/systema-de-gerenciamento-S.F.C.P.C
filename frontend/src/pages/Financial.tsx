import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useFinancialSummary } from '@/hooks/useFinancial';
import { formatCurrency, formatPercent } from '@/lib/utils';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';
import { TrendingUp } from 'lucide-react';
import { InvoiceUpload } from '@/components/InvoiceUpload';

export default function Financial() {
  const { data, isLoading } = useFinancialSummary();

  const summary = [
    { label: 'Receita', value: formatCurrency(data?.revenue ?? 0) },
    { label: 'Custos', value: formatCurrency(data?.costs ?? 0) },
    { label: 'Lucro', value: formatCurrency(data?.profit ?? 0) },
    { label: 'ROI', value: formatPercent(data?.roi ?? 0) },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Financeiro</h1>
        <p className="text-muted-foreground text-sm">Resumo financeiro do período</p>
      </div>

      <InvoiceUpload />

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {summary.map(({ label, value }) => (
          <Card key={label}>
            <CardHeader className="pb-1"><CardTitle className="text-sm text-muted-foreground">{label}</CardTitle></CardHeader>
            <CardContent><p className="text-xl font-bold">{isLoading ? '...' : value}</p></CardContent>
          </Card>
        ))}
      </div>
      <Card>
        <CardHeader><CardTitle className="flex items-center gap-2"><TrendingUp size={18} /> Receita vs Custo por Mês</CardTitle></CardHeader>
        <CardContent>
          {isLoading ? (
            <p className="text-muted-foreground text-sm py-8 text-center">Carregando...</p>
          ) : (
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={data?.monthly_breakdown ?? []}>
                <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
                <XAxis dataKey="month" className="text-xs" />
                <YAxis className="text-xs" tickFormatter={(v) => `R$${(v/1000).toFixed(0)}k`} />
                <Tooltip formatter={(v: number) => formatCurrency(v)} />
                <Legend />
                <Bar dataKey="revenue" name="Receita" fill="#22c55e" radius={[4, 4, 0, 0]} />
                <Bar dataKey="cost" name="Custo" fill="#f43f5e" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
