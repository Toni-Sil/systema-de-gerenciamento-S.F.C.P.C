import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { useProducts } from '@/hooks/useStock';
import { formatCurrency, getAbcColor } from '@/lib/utils';
import { Package } from 'lucide-react';

export default function Products() {
  const { data: products, isLoading, isError } = useProducts();

  if (isLoading) return <div className="flex items-center justify-center h-64"><p className="text-muted-foreground">Carregando produtos...</p></div>;
  if (isError) return <div className="flex items-center justify-center h-64"><p className="text-destructive">Erro ao carregar produtos. Verifique se o backend está rodando.</p></div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Produtos</h1>
          <p className="text-muted-foreground text-sm">{products?.length ?? 0} produtos cadastrados</p>
        </div>
      </div>

      {!products?.length ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-16">
            <Package size={48} className="text-muted-foreground mb-4" />
            <p className="text-muted-foreground">Nenhum produto cadastrado ainda.</p>
            <p className="text-xs text-muted-foreground mt-1">Conecte o backend para ver os dados.</p>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardHeader><CardTitle>Lista de Produtos</CardTitle></CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left">
                    <th className="pb-3 font-medium text-muted-foreground">SKU</th>
                    <th className="pb-3 font-medium text-muted-foreground">Nome</th>
                    <th className="pb-3 font-medium text-muted-foreground">Qtd</th>
                    <th className="pb-3 font-medium text-muted-foreground">Custo Unit.</th>
                    <th className="pb-3 font-medium text-muted-foreground">Classe ABC</th>
                    <th className="pb-3 font-medium text-muted-foreground">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {products.map((p) => (
                    <tr key={p.id} className="border-b last:border-0 hover:bg-muted/30 transition-colors">
                      <td className="py-3 font-mono text-xs">{p.sku}</td>
                      <td className="py-3">{p.name}</td>
                      <td className="py-3">{p.quantity}</td>
                      <td className="py-3">{formatCurrency(p.unit_cost)}</td>
                      <td className="py-3">
                        <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${getAbcColor(p.abc_class)}`}>
                          {p.abc_class ?? '—'}
                        </span>
                      </td>
                      <td className="py-3">
                        <Badge variant={p.quantity <= p.min_quantity ? 'destructive' : 'success'}>
                          {p.quantity <= p.min_quantity ? 'Baixo' : 'OK'}
                        </Badge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
