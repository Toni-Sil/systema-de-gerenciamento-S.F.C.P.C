import { useState, useRef } from 'react';
import { Button } from '@/components/ui/button';
import { FileUp, Sparkles, Loader2, CheckCircle2, ShieldAlert } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { useToast } from '@/hooks/use-toast';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';

export function InvoiceUpload() {
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<'idle' | 'uploading' | 'success'>('idle');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setLoading(true);
    setStatus('uploading');
    
    try {
      const buffer = await file.arrayBuffer();
      const base64 = btoa(
        new Uint8Array(buffer).reduce((s, b) => s + String.fromCharCode(b), "")
      );

      const res = await api.post("/ai/process-movement", {
        type: file.type.includes('pdf') ? 'pdf' : 'image',
        content: base64,
        mimeType: file.type,
      });

      if (res.movement.type === 'RegisterExpense' || res.movement.notes) {
          setStatus('success');
          toast({ 
            title: 'Documento processado!', 
            description: 'Ação enviada para o Portal de Governança para aprovação final.' 
          });
      } else {
          throw new Error("Não foi possível identificar uma despesa clara neste documento.");
      }
    } catch (err: any) {
      setStatus('idle');
      toast({ 
        title: 'Falha no processamento', 
        description: err.message,
        variant: 'destructive' 
      });
    } finally {
      setLoading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  return (
    <Card className="border-dashed bg-indigo-500/5 border-indigo-500/20 shadow-none overflow-hidden relative group">
      <div className="absolute top-0 right-0 p-2 opacity-20 group-hover:opacity-40 transition-opacity">
         <Sparkles size={40} className="text-indigo-400" />
      </div>
      
      <CardContent className="p-6">
        <div className="flex flex-col md:flex-row items-center gap-6">
            <div className={cn(
                "h-16 w-16 rounded-2xl flex items-center justify-center transition-all duration-500",
                status === 'success' ? 'bg-green-500/20 text-green-500' : 'bg-indigo-500/20 text-indigo-500'
            )}>
                {loading ? <Loader2 className="h-8 w-8 animate-spin" /> : 
                 status === 'success' ? <CheckCircle2 className="h-8 w-8" /> : 
                 <FileUp className="h-8 w-8" />}
            </div>

            <div className="flex-1 text-center md:text-left">
                <h3 className="font-bold text-lg mb-1">Upload Inteligente de Notas</h3>
                <p className="text-sm text-muted-foreground max-w-sm">
                   Arraste sua NF-e (PDF ou Imagem) e a IA fará a extração automática de valores e fornecedores.
                </p>
            </div>

            <div className="flex-shrink-0 flex gap-2">
                <input 
                    ref={fileInputRef}
                    type="file" 
                    accept=".pdf,image/*" 
                    className="hidden" 
                    onChange={handleFile}
                />
                <Button 
                    onClick={() => fileInputRef.current?.click()}
                    disabled={loading}
                    className="bg-indigo-600 hover:bg-indigo-500"
                >
                    Selecionar Arquivo
                </Button>
                <Button variant="outline" className="border-indigo-500/30 text-indigo-400" asChild>
                    <a href="/governance" className="flex items-center gap-2">
                       <ShieldAlert size={14} /> Ver Pendências
                    </a>
                </Button>
            </div>
        </div>
      </CardContent>
    </Card>
  );
}
