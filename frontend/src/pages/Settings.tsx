import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

export default function Settings() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Configurações</h1>
        <p className="text-muted-foreground text-sm">Preferências do sistema</p>
      </div>
      <Card>
        <CardHeader><CardTitle>API Backend</CardTitle></CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground mb-2">URL configurada:</p>
          <code className="text-sm bg-muted px-3 py-1.5 rounded">
            {import.meta.env.VITE_API_URL || 'http://localhost:8000'}
          </code>
        </CardContent>
      </Card>
    </div>
  );
}
