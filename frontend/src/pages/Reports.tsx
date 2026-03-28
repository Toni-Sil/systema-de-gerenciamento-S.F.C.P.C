import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { FileText, Download } from 'lucide-react';

const reports = [
  { title: 'Relatório Semanal de Estoque', description: 'Movimentações e balanço da semana', available: true },
  { title: 'Análise ABC Mensal', description: 'Classificação de produtos por valor', available: true },
  { title: 'ROI do Período', description: 'Retorno sobre investimento em estoque', available: true },
  { title: 'Previsão de Demanda', description: 'Forecast ML para os próximos 30 dias', available: false },
];

export default function Reports() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Relatórios</h1>
        <p className="text-muted-foreground text-sm">Gere e exporte relatórios do sistema</p>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {reports.map(({ title, description, available }) => (
          <Card key={title} className={!available ? 'opacity-60' : ''}>
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2 text-base">
                <FileText size={16} />
                {title}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground mb-4">{description}</p>
              <button
                disabled={!available}
                className="flex items-center gap-2 text-sm px-4 py-2 rounded-md bg-primary text-primary-foreground hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                <Download size={14} />
                {available ? 'Gerar PDF' : 'Em breve'}
              </button>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
