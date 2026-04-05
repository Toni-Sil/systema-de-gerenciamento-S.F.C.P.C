import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { api } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';
import { Sparkles, Save, BrainCircuit, Cloud } from 'lucide-react';

export default function Settings() {
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);
  const [settings, setSettings] = useState({
    llm_provider: 'gemini',
    gemini_api_key: '',
    ollama_url: 'http://localhost:11434',
    ollama_model: 'llama3',
  });

  useEffect(() => {
    api.get('/settings').then((res) => {
      // res can be null if not configured, the state defaults are okay.
      if (res) {
          setSettings(prev => ({...prev, ...res}));
      }
    });
  }, []);

  const handleSave = async () => {
    setLoading(true);
    try {
      await api.post('/settings', settings);
      toast({ 
        title: 'Configurações salvas!', 
        description: 'O sistema de IA foi atualizado para este tenant.' 
      });
    } catch (err) {
      toast({ 
        title: 'Erro ao salvar', 
        description: 'Não foi possível salvar as configurações no servidor.',
        variant: 'destructive' 
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <div className="flex flex-col gap-1">
        <h1 className="text-3xl font-bold tracking-tight">Configurações</h1>
        <p className="text-muted-foreground">Gerencie o motor de inteligência e preferências do tenant.</p>
      </div>

      <div className="grid gap-6">
        <Card className="border-white/10 bg-zinc-950/50 backdrop-blur-xl overflow-hidden shadow-2xl">
          <div className="h-1.5 w-full bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500" />
          <CardHeader className="pb-8">
            <div className="flex items-center gap-4">
               <div className="p-3 rounded-2xl bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                  <Sparkles size={24} />
               </div>
               <div>
                  <CardTitle className="text-xl">Inteligência Artificial (LLM)</CardTitle>
                  <CardDescription>Escolha o cérebro do S.F.C.P.C e configure os limites de processamento.</CardDescription>
               </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-8">
            <div className="space-y-4">
              <Label className="text-[10px] font-bold tracking-[0.2em] uppercase text-indigo-400/80">Provedor de IA Selecionado</Label>
              <RadioGroup 
                value={settings.llm_provider} 
                onValueChange={(val) => setSettings({ ...settings, llm_provider: val })}
                className="grid grid-cols-1 md:grid-cols-2 gap-4"
              >
                <Label
                  htmlFor="gemini"
                  className={`flex flex-col items-center justify-between rounded-2xl border-2 p-8 transition-all duration-300 cursor-pointer relative overflow-hidden ${
                    settings.llm_provider === 'gemini' 
                      ? 'border-indigo-500/50 bg-indigo-500/5 ring-1 ring-indigo-500/20' 
                      : 'border-white/5 bg-white/2 hover:border-white/10 hover:bg-white/[0.04]'
                  }`}
                >
                  <RadioGroupItem value="gemini" id="gemini" className="sr-only" />
                  <Cloud className={`h-10 w-10 mb-4 transition-colors ${settings.llm_provider === 'gemini' ? 'text-indigo-400' : 'text-white/20'}`} />
                  <div className="text-center">
                    <p className="font-bold text-lg">Google Gemini</p>
                    <p className="text-xs text-muted-foreground mt-1 max-w-[180px]">Nuvem de escala global (Flash 2.0). Requer chave de API externa.</p>
                  </div>
                  {settings.llm_provider === 'gemini' && (
                      <div className="absolute top-2 right-2 h-2 w-2 rounded-full bg-indigo-500 animate-pulse" />
                  )}
                </Label>

                <Label
                  htmlFor="ollama"
                  className={`flex flex-col items-center justify-between rounded-2xl border-2 p-8 transition-all duration-300 cursor-pointer relative overflow-hidden ${
                    settings.llm_provider === 'ollama' 
                      ? 'border-purple-500/50 bg-purple-500/5 ring-1 ring-purple-500/20' 
                      : 'border-white/5 bg-white/2 hover:border-white/10 hover:bg-white/[0.04]'
                  }`}
                >
                  <RadioGroupItem value="ollama" id="ollama" className="sr-only" />
                  <BrainCircuit className={`h-10 w-10 mb-4 transition-colors ${settings.llm_provider === 'ollama' ? 'text-purple-400' : 'text-white/20'}`} />
                  <div className="text-center">
                    <p className="font-bold text-lg">Ollama (Local)</p>
                    <p className="text-xs text-muted-foreground mt-1 max-w-[180px]">Processamento local. Máxima privacidade e zero custos de API.</p>
                  </div>
                   {settings.llm_provider === 'ollama' && (
                      <div className="absolute top-2 right-2 h-2 w-2 rounded-full bg-purple-500 animate-pulse" />
                  )}
                </Label>
              </RadioGroup>
            </div>

            <div className="grid gap-6 p-8 rounded-3xl bg-white/[0.03] border border-white/5 relative overflow-hidden group">
              <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/[0.02] to-transparent pointer-events-none" />
              
              {settings.llm_provider === 'gemini' ? (
                <div className="space-y-4 relative">
                  <div className="space-y-2">
                    <Label htmlFor="gemini_key" className="text-sm">Gemini API Key</Label>
                    <Input 
                      id="gemini_key"
                      type="password"
                      placeholder={settings.gemini_api_key === '***' ? 'Mantendo chave existente' : 'Cole sua chave aqui...'}
                      value={settings.gemini_api_key === '***' ? '' : settings.gemini_api_key}
                      onChange={(e) => setSettings({ ...settings, gemini_api_key: e.target.value })}
                      className="h-12 bg-black/40 border-white/10 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/20 transition-all rounded-xl"
                    />
                  </div>
                  <div className="flex items-center gap-2 p-3 rounded-xl bg-orange-500/10 border border-orange-500/20">
                     <p className="text-[10px] text-orange-400 font-medium">Nota: Sua chave é armazenada de forma segura e utilizada apenas para requisições do seu Tenant.</p>
                  </div>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6 relative">
                  <div className="space-y-2">
                    <Label htmlFor="ollama_url" className="text-sm">Endpoint do Servidor</Label>
                    <Input 
                        id="ollama_url"
                        placeholder="http://localhost:11434"
                        value={settings.ollama_url}
                        onChange={(e) => setSettings({ ...settings, ollama_url: e.target.value })}
                        className="h-12 bg-black/40 border-white/10 transition-all rounded-xl"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="ollama_model" className="text-sm">Nome do Modelo (Ollama)</Label>
                    <Input 
                        id="ollama_model"
                        placeholder="llama3"
                        value={settings.ollama_model}
                        onChange={(e) => setSettings({ ...settings, ollama_model: e.target.value })}
                        className="h-12 bg-black/40 border-white/10 transition-all rounded-xl"
                    />
                  </div>
                </div>
              )}
            </div>

            <Button 
                onClick={handleSave} 
                disabled={loading}
                className="w-full h-14 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 shadow-xl shadow-indigo-500/20 font-bold text-lg rounded-2xl active:scale-[0.98] transition-all"
            >
              {loading ? 'Salvando Alterações...' : <><Save className="mr-2 h-5 w-5" /> Salvar Configurações</>}
            </Button>
          </CardContent>
        </Card>

        {/* Informational Card */}
        <Card className="border-white/5 bg-white/[0.01] overflow-hidden">
           <CardContent className="p-6 flex items-center justify-between text-muted-foreground">
              <div className="text-xs">
                 Status: Configurações persistidas em Gold-Tier Storage
              </div>
              <div className="text-[10px] uppercase tracking-tighter">
                Tenant: Configurable AI Node
              </div>
           </CardContent>
        </Card>
      </div>
    </div>
  );
}
