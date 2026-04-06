import { useQuery } from '@tanstack/react-query';
import { Card, CardContent } from '@/components/ui/card';
import { Sparkles, Loader2 } from 'lucide-react';
import { api } from '@/lib/api';

export function AIInsightCard() {
  const { data, isLoading } = useQuery({
    queryKey: ['live-summary'],
    queryFn: async () => {
      const res = await api.get('/api/v1/intelligence/live-summary');
      return res.insight;
    },
    refetchOnWindowFocus: false,
    staleTime: 1000 * 60 * 5, // 5 minutes
  });

  return (
    <Card className="overflow-hidden border-none bg-gradient-to-br from-indigo-500/10 via-purple-500/5 to-transparent backdrop-blur-xl shadow-2xl relative group">
      {/* Animated Border/Glow effect */}
      <div className="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-indigo-400 to-transparent opacity-50" />
      
      <CardContent className="p-4 flex items-center gap-4">
        <div className="flex-shrink-0 h-10 w-10 rounded-xl bg-indigo-500/20 flex items-center justify-center text-indigo-400 animate-pulse">
           <Sparkles size={20} fill="currentColor" className="opacity-80" />
        </div>
        
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-0.5">
            <span className="text-[10px] font-bold tracking-widest text-indigo-400 uppercase">Insights da IA</span>
            {isLoading && <Loader2 size={10} className="animate-spin text-indigo-400/50" />}
          </div>
          <p className="text-sm font-medium text-foreground/90 line-clamp-2 leading-relaxed">
            {isLoading ? (
                <span className="opacity-40 italic">O Agente SFC-PC está analisando seus dados agora...</span>
            ) : (
                data || "Tudo certo por aqui! O estoque está sob controle."
            )}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
