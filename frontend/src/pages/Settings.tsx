import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { api } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';
import { Sparkles, Save, BrainCircuit, Cloud, FileText, Users, UserPlus, Trash2, Bot, Cpu, Zap } from 'lucide-react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Badge } from '@/components/ui/badge';

export default function Settings() {
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);
  const [settings, setSettings] = useState({
    llm_provider: 'gemini',
    gemini_api_key: '',
    gemini_model: 'gemini-2.5-flash',
    ollama_url: 'http://localhost:11434',
    ollama_model: 'llama3',
    openai_api_key: '',
    openai_model: 'gpt-4o',
    anthropic_api_key: '',
    anthropic_model: 'claude-3-7-sonnet-latest',
    groq_api_key: '',
    groq_model: 'llama-3.3-70b-versatile',
    service_order_url: '',
    service_order_api_key: '',
  });

  useEffect(() => {
    api.get('/api/v1/settings').then((res) => {
      if (res) {
          setSettings(prev => ({...prev, ...res}));
      }
    });
  }, []);

  const handleSave = async () => {
    setLoading(true);
    try {
      await api.post('/api/v1/settings', settings);
      toast({ 
        title: 'Configurações salvas!', 
        description: 'O sistema de IA foi atualizado para este tenant.' 
      });
    } catch (err: any) {
      toast({ 
        title: 'Erro ao salvar', 
        description: err.message,
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
        <p className="text-muted-foreground">Gerencie o motor de inteligência e preferências da empresa.</p>
      </div>

      <div className="grid gap-6">
        {/* IA Card */}
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
                onValueChange={(val: string) => setSettings({ ...settings, llm_provider: val })}
                className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
              >
                <Label htmlFor="gemini" className={`flex items-center gap-4 rounded-2xl border-2 p-4 transition-all duration-300 cursor-pointer ${settings.llm_provider === 'gemini' ? 'border-indigo-500/50 bg-indigo-500/5 ring-1 ring-indigo-500/20' : 'border-white/5 bg-white/2 hover:border-white/10 hover:bg-white/[0.04]'}`}>
                  <RadioGroupItem value="gemini" id="gemini" className="sr-only" />
                  <div className="p-3 rounded-full bg-indigo-500/10">
                    <Cloud className={`h-6 w-6 transition-colors ${settings.llm_provider === 'gemini' ? 'text-indigo-400' : 'text-white/40'}`} />
                  </div>
                  <div>
                    <p className="font-bold text-sm">Google Gemini</p>
                    <p className="text-[10px] text-muted-foreground">Velocidade e Nuvem</p>
                  </div>
                </Label>

                <Label htmlFor="openai" className={`flex items-center gap-4 rounded-2xl border-2 p-4 transition-all duration-300 cursor-pointer ${settings.llm_provider === 'openai' ? 'border-green-500/50 bg-green-500/5 ring-1 ring-green-500/20' : 'border-white/5 bg-white/2 hover:border-white/10 hover:bg-white/[0.04]'}`}>
                  <RadioGroupItem value="openai" id="openai" className="sr-only" />
                  <div className="p-3 rounded-full bg-green-500/10">
                    <Bot className={`h-6 w-6 transition-colors ${settings.llm_provider === 'openai' ? 'text-green-400' : 'text-white/40'}`} />
                  </div>
                  <div>
                    <p className="font-bold text-sm">OpenAI (GPT)</p>
                    <p className="text-[10px] text-muted-foreground">O mais polivalente</p>
                  </div>
                </Label>

                <Label htmlFor="anthropic" className={`flex items-center gap-4 rounded-2xl border-2 p-4 transition-all duration-300 cursor-pointer ${settings.llm_provider === 'anthropic' ? 'border-amber-500/50 bg-amber-500/5 ring-1 ring-amber-500/20' : 'border-white/5 bg-white/2 hover:border-white/10 hover:bg-white/[0.04]'}`}>
                  <RadioGroupItem value="anthropic" id="anthropic" className="sr-only" />
                  <div className="p-3 rounded-full bg-amber-500/10">
                    <Cpu className={`h-6 w-6 transition-colors ${settings.llm_provider === 'anthropic' ? 'text-amber-400' : 'text-white/40'}`} />
                  </div>
                  <div>
                    <p className="font-bold text-sm">Anthropic</p>
                    <p className="text-[10px] text-muted-foreground">Foco em lógica Claude</p>
                  </div>
                </Label>

                <Label htmlFor="groq" className={`flex items-center gap-4 rounded-2xl border-2 p-4 transition-all duration-300 cursor-pointer ${settings.llm_provider === 'groq' ? 'border-red-500/50 bg-red-500/5 ring-1 ring-red-500/20' : 'border-white/5 bg-white/2 hover:border-white/10 hover:bg-white/[0.04]'}`}>
                  <RadioGroupItem value="groq" id="groq" className="sr-only" />
                  <div className="p-3 rounded-full bg-red-500/10">
                    <Zap className={`h-6 w-6 transition-colors ${settings.llm_provider === 'groq' ? 'text-red-400' : 'text-white/40'}`} />
                  </div>
                  <div>
                    <p className="font-bold text-sm">Groq API</p>
                    <p className="text-[10px] text-muted-foreground">Inferência Ultra Rápida</p>
                  </div>
                </Label>

                <Label htmlFor="ollama" className={`flex items-center gap-4 rounded-2xl border-2 p-4 transition-all duration-300 cursor-pointer ${settings.llm_provider === 'ollama' ? 'border-purple-500/50 bg-purple-500/5 ring-1 ring-purple-500/20' : 'border-white/5 bg-white/2 hover:border-white/10 hover:bg-white/[0.04]'}`}>
                  <RadioGroupItem value="ollama" id="ollama" className="sr-only" />
                  <div className="p-3 rounded-full bg-purple-500/10">
                    <BrainCircuit className={`h-6 w-6 transition-colors ${settings.llm_provider === 'ollama' ? 'text-purple-400' : 'text-white/40'}`} />
                  </div>
                  <div>
                    <p className="font-bold text-sm">Ollama Local</p>
                    <p className="text-[10px] text-muted-foreground">Privacidade Máxima</p>
                  </div>
                </Label>
              </RadioGroup>
            </div>

            <div className="grid gap-6 p-8 rounded-3xl bg-white/[0.03] border border-white/5">
              {settings.llm_provider === 'gemini' && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <Label htmlFor="gemini_key" className="text-sm">Gemini API Key</Label>
                    <Input 
                      id="gemini_key" type="password"
                      placeholder={settings.gemini_api_key === '***' ? 'Mantendo chave existente' : 'Cole sua chave aqui...'}
                      value={settings.gemini_api_key === '***' ? '' : settings.gemini_api_key}
                      onChange={(e) => setSettings({ ...settings, gemini_api_key: e.target.value })}
                      className="h-12 bg-black/40 border-white/10 rounded-xl"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="gemini_model" className="text-sm">Modelo Desejado</Label>
                    <Select value={settings.gemini_model || 'gemini-2.5-flash'} onValueChange={(val) => setSettings({ ...settings, gemini_model: val })}>
                      <SelectTrigger id="gemini_model" className="h-12 bg-black/40 border-white/10 rounded-xl">
                        <SelectValue placeholder="Selecione um modelo..." />
                      </SelectTrigger>
                      <SelectContent className="bg-zinc-900 border-white/10 text-white rounded-xl">
                        <SelectItem value="gemini-2.5-flash">gemini-2.5-flash (Ideal p/ Chat)</SelectItem>
                        <SelectItem value="gemini-1.5-pro-latest">gemini-1.5-pro-latest (Análises Pesadas)</SelectItem>
                        <SelectItem value="gemini-1.5-flash-latest">gemini-1.5-flash-latest</SelectItem>
                        <SelectItem value="gemini-2.0-pro-exp">gemini-2.0-pro-exp</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              )}
              {settings.llm_provider === 'openai' && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <Label htmlFor="openai_key" className="text-sm">OpenAI API Key</Label>
                    <Input id="openai_key" type="password" placeholder={settings.openai_api_key === '***' ? 'Mantendo chave existente' : 'sk-...'} value={settings.openai_api_key === '***' ? '' : settings.openai_api_key} onChange={(e) => setSettings({ ...settings, openai_api_key: e.target.value })} className="h-12 bg-black/40 border-white/10 rounded-xl" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="openai_model" className="text-sm">Modelo Desejado</Label>
                    <Select value={settings.openai_model || 'gpt-4o'} onValueChange={(val) => setSettings({ ...settings, openai_model: val })}>
                      <SelectTrigger id="openai_model" className="h-12 bg-black/40 border-white/10 rounded-xl">
                        <SelectValue placeholder="Selecione um modelo..." />
                      </SelectTrigger>
                      <SelectContent className="bg-zinc-900 border-white/10 text-white rounded-xl">
                        <SelectItem value="gpt-4o">gpt-4o (Polivalente)</SelectItem>
                        <SelectItem value="gpt-4o-mini">gpt-4o-mini (Rápido e barato)</SelectItem>
                        <SelectItem value="o3-mini">o3-mini (Raciocínio Lógico)</SelectItem>
                        <SelectItem value="gpt-4-turbo">gpt-4-turbo</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              )}
              {settings.llm_provider === 'anthropic' && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <Label htmlFor="anthropic_key" className="text-sm">Anthropic API Key</Label>
                    <Input id="anthropic_key" type="password" placeholder={settings.anthropic_api_key === '***' ? 'Mantendo chave existente' : 'sk-ant-...'} value={settings.anthropic_api_key === '***' ? '' : settings.anthropic_api_key} onChange={(e) => setSettings({ ...settings, anthropic_api_key: e.target.value })} className="h-12 bg-black/40 border-white/10 rounded-xl" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="anthropic_model" className="text-sm">Modelo Desejado</Label>
                    <Select value={settings.anthropic_model || 'claude-3-7-sonnet-latest'} onValueChange={(val) => setSettings({ ...settings, anthropic_model: val })}>
                      <SelectTrigger id="anthropic_model" className="h-12 bg-black/40 border-white/10 rounded-xl">
                        <SelectValue placeholder="Selecione um modelo..." />
                      </SelectTrigger>
                      <SelectContent className="bg-zinc-900 border-white/10 text-white rounded-xl">
                        <SelectItem value="claude-3-7-sonnet-latest">claude-3-7-sonnet (O Melhor)</SelectItem>
                        <SelectItem value="claude-3-5-sonnet-latest">claude-3-5-sonnet (Excelente Geral)</SelectItem>
                        <SelectItem value="claude-3-5-haiku-20241022">claude-3-5-haiku (Extremo Ágil)</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              )}
              {settings.llm_provider === 'groq' && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <Label htmlFor="groq_key" className="text-sm">Groq API Key</Label>
                    <Input id="groq_key" type="password" placeholder={settings.groq_api_key === '***' ? 'Mantendo chave existente' : 'gsk_...'} value={settings.groq_api_key === '***' ? '' : settings.groq_api_key} onChange={(e) => setSettings({ ...settings, groq_api_key: e.target.value })} className="h-12 bg-black/40 border-white/10 rounded-xl" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="groq_model" className="text-sm">Modelo Desejado (Open Source)</Label>
                    <Select value={settings.groq_model || 'llama-3.3-70b-versatile'} onValueChange={(val) => setSettings({ ...settings, groq_model: val })}>
                      <SelectTrigger id="groq_model" className="h-12 bg-black/40 border-white/10 rounded-xl">
                        <SelectValue placeholder="Selecione um modelo..." />
                      </SelectTrigger>
                      <SelectContent className="bg-zinc-900 border-white/10 text-white rounded-xl">
                        <SelectItem value="llama-3.3-70b-versatile">llama-3.3-70b-versatile</SelectItem>
                        <SelectItem value="llama-3.1-8b-instant">llama-3.1-8b-instant</SelectItem>
                        <SelectItem value="mixtral-8x7b-32768">mixtral-8x7b-32768</SelectItem>
                        <SelectItem value="gemma2-9b-it">gemma2-9b-it</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              )}
              {settings.llm_provider === 'ollama' && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <Label htmlFor="ollama_url" className="text-sm">Endpoint do Servidor</Label>
                    <Input id="ollama_url" placeholder="http://localhost:11434" value={settings.ollama_url} onChange={(e) => setSettings({ ...settings, ollama_url: e.target.value })} className="h-12 bg-black/40 border-white/10 rounded-xl" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="ollama_model" className="text-sm">Modelo (Instalado Localmente)</Label>
                    <Input id="ollama_model" placeholder="Ex: llama3, phi4, qwen2.5:7b" value={settings.ollama_model || 'llama3'} onChange={(e) => setSettings({ ...settings, ollama_model: e.target.value })} className="h-12 bg-black/40 border-white/10 rounded-xl" />
                    <p className="text-[10px] text-muted-foreground">Você deve digitar exatamente como baixou.</p>
                  </div>
                </div>
              )}
            </div>

            <Button onClick={handleSave} disabled={loading} className="w-full h-14 bg-gradient-to-r from-indigo-600 to-purple-600 rounded-2xl active:scale-[0.98] transition-all">
              {loading ? 'Salvando Alterações...' : <><Save className="mr-2 h-5 w-5" /> Salvar Configurações</>}
            </Button>
          </CardContent>
        </Card>

        {/* OS Integration */}
        <Card className="border-white/10 bg-zinc-950/50 backdrop-blur-xl overflow-hidden shadow-2xl">
          <CardHeader className="pb-8">
            <div className="flex items-center gap-4">
               <div className="p-3 rounded-2xl bg-orange-500/10 text-orange-400 border border-orange-500/20">
                  <FileText size={24} />
               </div>
               <div>
                  <CardTitle className="text-xl">Sistema de Ordem de Serviço (Externo)</CardTitle>
                  <CardDescription>Conecte o S.F.C.P.C ao sistema externo de gerenciamento de reformas.</CardDescription>
               </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 p-8 rounded-3xl bg-white/[0.03] border border-white/5">
              <div className="space-y-2">
                <Label htmlFor="os_url" className="text-sm">URL do Sistema de OS</Label>
                <Input id="os_url" placeholder="https://os-system.vercel.app" value={settings.service_order_url} onChange={(e) => setSettings({ ...settings, service_order_url: e.target.value })} className="h-12 bg-black/40 border-white/10 rounded-xl" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="os_key" className="text-sm">API Key</Label>
                <Input id="os_key" type="password" placeholder={settings.service_order_api_key === '***' ? 'Mantendo chave existente' : ''} value={settings.service_order_api_key === '***' ? '' : settings.service_order_api_key} onChange={(e) => setSettings({ ...settings, service_order_api_key: e.target.value })} className="h-12 bg-black/40 border-white/10 rounded-xl" />
              </div>
            </div>
            <Button onClick={handleSave} disabled={loading} className="w-full h-12 bg-white/5 hover:bg-white/10 border border-white/10 rounded-xl">
               Atualizar Credenciais OS
            </Button>
          </CardContent>
        </Card>

        {/* Team Management */}
        <TeamManagement />

        {/* Status */}
        <Card className="border-white/5 bg-white/[0.01]">
           <CardContent className="p-6 flex items-center justify-between text-muted-foreground">
              <div className="text-xs">Status: Configurações persistidas em Gold-Tier Storage</div>
              <div className="text-[10px] uppercase tracking-tighter">Tenant Mode: Enterprise</div>
           </CardContent>
        </Card>
      </div>
    </div>
  );
}

function TeamManagement() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [newUser, setNewUser] = useState({ username: '', email: '', plain_password: '', role: 'operator' });

  const { data: team, isLoading } = useQuery({
    queryKey: ['team-members'],
    queryFn: () => api.get('/api/v1/users'),
  });

  const addMutation = useMutation({
    mutationFn: (data: any) => api.post('/api/v1/users', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['team-members'] });
      setNewUser({ username: '', email: '', plain_password: '', role: 'operator' });
      toast({ title: 'Operador adicionado!' });
    },
    onError: (err: any) => toast({ title: 'Erro ao adicionar', description: err.message, variant: 'destructive' })
  });

  const removeMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/users/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['team-members'] });
      toast({ title: 'Usuário removido.' });
    }
  });

  return (
    <Card className="border-white/10 bg-zinc-950/50 backdrop-blur-xl overflow-hidden shadow-2xl">
      <CardHeader className="pb-8">
        <div className="flex items-center gap-4">
           <div className="p-3 rounded-2xl bg-purple-500/10 text-purple-400 border border-purple-500/20">
              <Users size={24} />
           </div>
           <div>
              <CardTitle className="text-xl">Gestão da Equipe (Operadores)</CardTitle>
              <CardDescription>Gerencie quem tem acesso ao sistema e quais são suas permissões.</CardDescription>
           </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-8">
        <div className="grid gap-4">
           {isLoading ? (
             <div className="p-4 text-center text-muted-foreground animate-pulse">Carregando equipe...</div>
           ) : team?.map((user: any) => (
             <div key={user.id} className="flex items-center justify-between p-4 rounded-2xl bg-white/5 border border-white/10 group">
                <div className="flex items-center gap-4">
                   <div className="h-10 w-10 rounded-full bg-indigo-500/10 flex items-center justify-center text-indigo-400 font-bold uppercase">
                      {user.username[0]}
                   </div>
                   <div>
                      <p className="font-bold text-sm">{user.username}</p>
                      <p className="text-[10px] text-muted-foreground">{user.role}</p>
                   </div>
                </div>
                {user.role !== 'admin' && (
                  <Button variant="ghost" size="icon" className="h-8 w-8 text-white/20 hover:text-red-400" onClick={() => removeMutation.mutate(user.id)}>
                    <Trash2 size={14} />
                  </Button>
                )}
             </div>
           ))}
        </div>

        <div className="p-6 rounded-3xl bg-white/[0.03] border border-white/5 space-y-4">
           <div className="flex items-center gap-2 text-xs font-bold text-white/40 uppercase"><UserPlus size={14} /> Novo Operador</div>
           <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input placeholder="Nome" value={newUser.username} onChange={e => setNewUser({...newUser, username: e.target.value})} className="bg-black/40 border-white/10" />
              <Input placeholder="E-mail" value={newUser.email} onChange={e => setNewUser({...newUser, email: e.target.value})} className="bg-black/40 border-white/10" />
              <Input type="password" placeholder="Senha" value={newUser.plain_password} onChange={e => setNewUser({...newUser, plain_password: e.target.value})} className="bg-black/40 border-white/10" />
              <select value={newUser.role} onChange={e => setNewUser({...newUser, role: e.target.value})} className="flex h-10 w-full rounded-md border border-white/10 bg-black/40 px-3 py-2 text-sm">
                 <option value="operator">Operador</option>
                 <option value="manager">Gerente</option>
                 <option value="auditor">Auditor</option>
              </select>
           </div>
           <Button className="w-full bg-indigo-600 hover:bg-indigo-500" onClick={() => addMutation.mutate(newUser)} disabled={!newUser.username || !newUser.plain_password}>
              Cadastrar Operador
           </Button>
        </div>
      </CardContent>
    </Card>
  );
}
