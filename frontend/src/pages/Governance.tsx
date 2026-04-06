import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { api } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';
import { 
  ShieldAlert, 
  CheckCircle2, 
  XCircle, 
  Clock, 
  BrainCircuit,
  ArrowRightLeft,
  Package
} from 'lucide-react';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

interface PendingAction {
  id: string;
  action_type: string;
  proposed_params: any;
  risk_level: 'low' | 'medium' | 'high';
  risk_reason: string;
  raw_message: string;
  created_at: string;
}

export default function Governance() {
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: actions, isLoading } = useQuery<PendingAction[]>({
    queryKey: ['pending-actions'],
    queryFn: () => api.get('/governance/pending'),
  });

  const approveMutation = useMutation({
    mutationFn: (id: string) => api.post(`/governance/approve/${id}`, {}),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pending-actions'] });
      toast({ title: 'Ação aprovada!', description: 'O estoque foi atualizado com sucesso.' });
    },
  });

  const rejectMutation = useMutation({
    mutationFn: (id: string) => api.post(`/governance/reject/${id}`, {}),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pending-actions'] });
      toast({ title: 'Ação rejeitada', variant: 'destructive' });
    },
  });

  if (isLoading) return <div className="p-8 text-center text-muted-foreground animate-pulse">Carregando portal de segurança...</div>;

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <div className="flex flex-col gap-1">
        <div className="flex items-center gap-2">
            <ShieldAlert className="text-indigo-500 h-6 w-6" />
            <h1 className="text-3xl font-bold tracking-tight">Portal de Governança</h1>
        </div>
        <p className="text-muted-foreground">Revise e autorize ações sugeridas pela inteligência artificial.</p>
      </div>

      {!actions?.length ? (
        <div className="flex flex-col items-center justify-center py-20 bg-white/[0.02] rounded-3xl border border-dashed border-white/10">
           <div className="h-16 w-16 rounded-full bg-green-500/10 flex items-center justify-center text-green-500 mb-4">
              <CheckCircle2 className="h-8 w-8" />
           </div>
           <p className="text-lg font-medium">Tudo sob controle</p>
           <p className="text-sm text-muted-foreground">Não há ações pendentes de aprovação no momento.</p>
        </div>
      ) : (
        <div className="grid gap-6">
          {actions.map((action) => (
            <Card key={action.id} className="border-white/10 bg-zinc-950/50 backdrop-blur-xl overflow-hidden shadow-2xl relative group">
              <div className={cn(
                "absolute left-0 top-0 bottom-0 w-1.5",
                action.risk_level === 'high' ? 'bg-red-500' : 'bg-yellow-500'
              )} />
              
              <CardContent className="p-0">
                <div className="grid grid-cols-1 lg:grid-cols-4 gap-0">
                  
                  {/* Context info */}
                  <div className="p-6 border-r border-white/5 space-y-4">
                    <div className="flex items-center gap-2">
                        <Badge variant={action.risk_level === 'high' ? 'destructive' : 'warning'} className="uppercase text-[9px] tracking-widest">
                           Risco {action.risk_level}
                        </Badge>
                        <div className="flex items-center gap-1 text-[10px] text-muted-foreground">
                           <Clock size={12} />
                           {format(new Date(action.created_at), 'HH:mm', { locale: ptBR })}
                        </div>
                    </div>
                    <div>
                        <p className="text-[10px] uppercase font-bold text-white/40 mb-1">Ação Detectada</p>
                        <div className="flex items-center gap-2 font-bold text-lg">
                            {action.action_type === 'Entry' ? <Package className="text-green-400" /> : <ArrowRightLeft className="text-orange-400" />}
                            {action.action_type === 'Entry' ? 'Entrada de Mercadoria' : 'Saída de Estoque'}
                        </div>
                    </div>
                    <div className="p-3 rounded-xl bg-white/5 border border-white/5 text-xs italic text-muted-foreground">
                        "{action.raw_message?.substring(0, 80)}..."
                    </div>
                  </div>

                  {/* Proposed Params */}
                  <div className="lg:col-span-2 p-6 space-y-6">
                     <div className="flex items-center gap-2 text-indigo-400">
                        <BrainCircuit size={18} />
                        <span className="text-sm font-semibold uppercase tracking-wider">Sugestão da Inteligência</span>
                     </div>
                     
                     <div className="grid grid-cols-2 gap-4">
                        <div className="space-y-1">
                           <p className="text-[10px] uppercase text-white/40">Produto</p>
                           <p className="font-medium">{action.proposed_params?.product || 'Não identificado'}</p>
                        </div>
                        <div className="space-y-1">
                           <p className="text-[10px] uppercase text-white/40">Quantidade</p>
                           <p className="text-2xl font-bold">{action.proposed_params?.quantity || 0}</p>
                        </div>
                     </div>

                     <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 flex gap-3 items-start">
                        <ShieldAlert className="text-red-500 h-5 w-5 mt-0.5" />
                        <div className="space-y-1">
                           <p className="text-xs font-bold text-red-500 uppercase italic">Motivo do Bloqueio</p>
                           <p className="text-sm text-white/80">{action.risk_reason}</p>
                        </div>
                     </div>
                  </div>

                  {/* Actions */}
                  <div className="p-6 bg-white/[0.02] flex flex-col gap-3 justify-center">
                     <Button 
                        onClick={() => approveMutation.mutate(action.id)}
                        disabled={approveMutation.isPending}
                        className="w-full bg-green-600 hover:bg-green-500 h-12 rounded-xl border-b-4 border-green-800 active:border-b-0 active:mt-1 transition-all"
                     >
                        <CheckCircle2 className="mr-2 h-4 w-4" /> Aprovar Ação
                     </Button>
                     <Button 
                        onClick={() => rejectMutation.mutate(action.id)}
                        disabled={rejectMutation.isPending}
                        variant="ghost" 
                        className="w-full text-red-400 hover:text-red-300 hover:bg-red-500/10 h-12"
                     >
                        <XCircle className="mr-2 h-4 w-4" /> Rejeitar
                     </Button>
                  </div>

                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

function cn(...classes: any[]) {
  return classes.filter(Boolean).join(' ');
}
