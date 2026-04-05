import { useState, useRef, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { 
  Mic, 
  FileText, 
  Loader2, 
  CheckCircle2, 
  AlertCircle, 
  Sparkles, 
  ChevronRight,
  ScanLine
} from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { api } from "@/lib/api";
import { cn } from "@/lib/utils";

type MovementData = {
  productName?: string;
  type?: string;
  quantity?: number;
  batch?: string;
  locationOrigin?: string;
  locationDestiny?: string;
  notes?: string;
  operator?: string;
};

type AIInputProps = {
  onDataExtracted: (data: MovementData) => void;
  variant?: "floating" | "inline";
};

type ProcessingState = "idle" | "recording" | "processing" | "success" | "error";

export function AIMovementInput({ onDataExtracted, variant = "inline" }: AIInputProps) {
  const { toast } = useToast();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [state, setState] = useState<ProcessingState>("idle");
  const [statusMessage, setStatusMessage] = useState("");
  const [transcript, setTranscript] = useState("");
  const [audioLevel, setAudioLevel] = useState(0);
  
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const animationRef = useRef<number | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pdfInputRef = useRef<HTMLInputElement>(null);

  const reset = () => {
    setState("idle");
    setStatusMessage("");
    setTranscript("");
    setAudioLevel(0);
    if (animationRef.current) cancelAnimationFrame(animationRef.current);
  };

  const startRecording = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      
      // Setup Visualizer
      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      const source = audioContext.createMediaStreamSource(stream);
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 256;
      source.connect(analyser);
      analyserRef.current = analyser;
      
      const updateLevel = () => {
        const dataArray = new Uint8Array(analyser.frequencyBinCount);
        analyser.getByteFrequencyData(dataArray);
        const average = dataArray.reduce((a, b) => a + b) / dataArray.length;
        setAudioLevel(average / 128); // Normalize to 0-1
        animationRef.current = requestAnimationFrame(updateLevel);
      };
      updateLevel();

      const mediaRecorder = new MediaRecorder(stream, { mimeType: "audio/webm" });
      mediaRecorderRef.current = mediaRecorder;
      chunksRef.current = [];
      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };
      mediaRecorder.onstop = async () => {
        stream.getTracks().forEach((t) => t.stop());
        audioContext.close();
        if (animationRef.current) cancelAnimationFrame(animationRef.current);
        const blob = new Blob(chunksRef.current, { type: "audio/webm" });
        await processVoice(blob);
      };
      mediaRecorder.start();
      setState("recording");
      setStatusMessage("Diga o que você deseja registrar...");
      setDialogOpen(true);
    } catch {
      toast({
        title: "Erro no microfone",
        description: "Não conseguimos acessar seu áudio. Verifique as permissões.",
        variant: "destructive",
      });
    }
  }, [toast]);

  const stopRecording = useCallback(() => {
    mediaRecorderRef.current?.stop();
    setState("processing");
    setStatusMessage("A inteligência está processando sua voz...");
  }, []);

  const processVoice = async (blob: Blob) => {
    try {
      const buffer = await blob.arrayBuffer();
      const base64 = btoa(
        new Uint8Array(buffer).reduce((s, b) => s + String.fromCharCode(b), "")
      );

      const transcribeRes = await api.post("/ai/transcribe-audio", {
        audio: base64,
        mimeType: "audio/webm",
      });
      const text = transcribeRes.transcript;
      setTranscript(text);
      
      const extractRes = await api.post("/ai/process-movement", {
        type: "voice",
        content: text,
      });
      handleSuccess(extractRes.movement);
    } catch (e: any) {
      handleError(e.message || "Erro ao interpretar comando");
    }
  };

  const handleFileUpload = async (file: File, inputType: "image" | "pdf") => {
    setDialogOpen(true);
    setState("processing");
    setStatusMessage(`Lendo seu ${inputType === "pdf" ? "documento" : "registro"}...`);
    try {
      const buffer = await file.arrayBuffer();
      const base64 = btoa(
        new Uint8Array(buffer).reduce((s, b) => s + String.fromCharCode(b), "")
      );
      const res = await api.post("/ai/process-movement", {
        type: inputType,
        content: base64,
        mimeType: file.type,
      });
      handleSuccess(res.movement);
    } catch (e: any) {
      handleError(e.message || `Falha ao processar arquivo`);
    }
  };

  const handleSuccess = (movementData: MovementData) => {
    setState("success");
    setStatusMessage("Movimentação identificada!");
    onDataExtracted(movementData);
    setTimeout(() => {
      setDialogOpen(false);
      reset();
    }, 2000);
  };

  const handleError = (message: string) => {
    setState("error");
    setStatusMessage(message);
  };

  const ActionCard = ({ 
    icon: Icon, 
    label, 
    onClick, 
    className 
  }: { 
    icon: any, 
    label: string, 
    onClick: () => void, 
    className?: string 
  }) => (
    <button
      onClick={onClick}
      className={cn(
        "group flex flex-col items-center justify-center gap-3 p-6 rounded-2xl transition-all duration-300",
        "bg-white/5 border border-white/10 hover:bg-white/10 hover:border-white/20 hover:scale-105 active:scale-95",
        "shadow-[0_8px_30px_rgb(0,0,0,0.12)] backdrop-blur-md",
        className
      )}
    >
      <div className="p-3 rounded-xl bg-gradient-to-br from-primary/20 to-primary/5 text-primary group-hover:scale-110 transition-transform">
        <Icon className="h-6 w-6" />
      </div>
      <span className="text-sm font-medium text-foreground/80">{label}</span>
    </button>
  );

  return (
    <>
      {variant === "inline" ? (
        <div className="grid grid-cols-3 gap-3 w-full">
          <ActionCard icon={Mic} label="Voz" onClick={startRecording} />
          <ActionCard icon={ScanLine} label="Scan" onClick={() => fileInputRef.current?.click()} />
          <ActionCard icon={FileText} label="Documento" onClick={() => pdfInputRef.current?.click()} />
        </div>
      ) : (
        <button
          onClick={() => setDialogOpen(true)}
          className={cn(
            "fixed bottom-20 right-6 lg:bottom-6 lg:right-6 z-50",
            "h-14 w-14 rounded-full flex items-center justify-center",
            "bg-gradient-to-tr from-indigo-600 via-violet-600 to-purple-600",
            "text-white shadow-[0_0_20px_rgba(79,70,229,0.4)] hover:shadow-[0_0_30px_rgba(79,70,229,0.6)]",
            "hover:scale-110 active:scale-95 transition-all duration-300 animate-in zoom-in slide-in-from-bottom-10"
          )}
        >
          <Sparkles className="h-6 w-6 fill-white/20" />
        </button>
      )}

      {/* Hidden Inputs */}
      <input 
        ref={fileInputRef} 
        type="file" 
        accept="image/*" 
        capture="environment" 
        className="hidden" 
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) handleFileUpload(file, "image");
          e.target.value = "";
        }}
      />
      <input 
        ref={pdfInputRef} 
        type="file" 
        accept=".pdf" 
        className="hidden" 
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) handleFileUpload(file, "pdf");
          e.target.value = "";
        }}
      />

      <Dialog 
        open={dialogOpen} 
        onOpenChange={(open) => {
          if (!open) {
            if (state === "recording") stopRecording();
            else { setDialogOpen(false); reset(); }
          }
        }}
      >
        <DialogContent className="sm:max-w-md bg-zinc-950/95 border-white/10 backdrop-blur-2xl text-white overflow-hidden p-0 rounded-3xl">
          <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500" />
          
          <div className="p-8">
            <DialogHeader className="mb-8">
              <div className="flex items-center gap-2 mb-2">
                <Sparkles className="h-4 w-4 text-indigo-400 fill-indigo-400/20" />
                <span className="text-[10px] font-bold tracking-[0.2em] uppercase text-indigo-400">Smart Assistant</span>
              </div>
              <DialogTitle className="text-2xl font-semibold tracking-tight">
                {state === "idle" ? "Como deseja registrar?" : "SFC-PC Inteligente"}
              </DialogTitle>
            </DialogHeader>

            {state === "idle" && (
              <div className="grid grid-cols-2 gap-4">
                <button
                  onClick={startRecording}
                  className="group relative flex flex-col items-center gap-4 p-8 rounded-3xl bg-white/5 border border-white/5 hover:bg-white/10 hover:border-indigo-500/50 transition-all duration-500"
                >
                  <div className="h-16 w-16 rounded-full bg-gradient-to-tr from-indigo-600 to-violet-600 flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                    <Mic className="h-8 w-8 text-white" />
                  </div>
                  <span className="font-medium">Comando de Voz</span>
                  <div className="absolute -bottom-1 -right-1 p-1 bg-indigo-500 rounded-full scale-0 group-hover:scale-100 transition-transform">
                    <ChevronRight className="h-3 w-3" />
                  </div>
                </button>

                <button
                  onClick={() => fileInputRef.current?.click()}
                  className="group relative flex flex-col items-center gap-4 p-8 rounded-3xl bg-white/5 border border-white/5 hover:bg-white/10 hover:border-purple-500/50 transition-all duration-500"
                >
                  <div className="h-16 w-16 rounded-full bg-gradient-to-tr from-purple-600 to-pink-600 flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                    <ScanLine className="h-8 w-8 text-white" />
                  </div>
                  <span className="font-medium">Escanear Foto</span>
                  <div className="absolute -bottom-1 -right-1 p-1 bg-purple-500 rounded-full scale-0 group-hover:scale-100 transition-transform">
                    <ChevronRight className="h-3 w-3" />
                  </div>
                </button>

                <button
                   onClick={() => pdfInputRef.current?.click()}
                   className="col-span-2 flex items-center justify-between p-4 px-6 rounded-2xl bg-white/5 border border-white/5 hover:bg-white/10 hover:border-white/20 transition-all"
                >
                  <div className="flex items-center gap-4">
                    <div className="h-10 w-10 rounded-xl bg-orange-500/20 text-orange-500 flex items-center justify-center">
                      <FileText className="h-5 w-5" />
                    </div>
                    <span className="font-medium">Importar PDF/Nota Fiscal</span>
                  </div>
                  <ChevronRight className="h-4 w-4 text-muted-foreground" />
                </button>
              </div>
            )}

            {(state === "recording" || state === "processing") && (
              <div className="flex flex-col items-center py-10 gap-10">
                {state === "recording" && (
                   <div className="relative">
                      <div className="absolute inset-0 bg-red-500/20 rounded-full blur-2xl animate-pulse" />
                      <div className="relative h-32 w-32 rounded-full border-4 border-red-500/30 flex items-center justify-center">
                        <div 
                          className="h-24 w-24 rounded-full bg-red-500 flex items-center justify-center transition-transform duration-75"
                          style={{ transform: `scale(${1 + audioLevel * 0.5})` }}
                        >
                          <Mic className="h-10 w-10 text-white" />
                        </div>
                      </div>
                   </div>
                )}

                {state === "processing" && (
                  <div className="flex flex-col items-center gap-6">
                    <div className="relative h-24 w-24">
                      <Loader2 className="h-24 w-24 text-indigo-500 animate-[spin_2s_linear_infinite]" />
                      <div className="absolute inset-0 flex items-center justify-center">
                        <Sparkles className="h-8 w-8 text-indigo-400 animate-pulse" />
                      </div>
                    </div>
                  </div>
                )}

                <div className="text-center space-y-2">
                  <p className="text-xl font-medium tracking-tight text-white/90">{statusMessage}</p>
                  {transcript && (
                    <p className="text-sm text-indigo-300 italic max-w-xs mx-auto">&ldquo;{transcript}&rdquo;</p>
                  )}
                </div>

                {state === "recording" && (
                  <Button 
                    onClick={stopRecording} 
                    variant="destructive" 
                    className="w-full h-14 rounded-2xl font-bold bg-zinc-900 border border-red-500/50 hover:bg-red-500 hover:text-white transition-all shadow-xl"
                  >
                    Encerrar e Processar
                  </Button>
                )}
              </div>
            )}

            {state === "success" && (
              <div className="flex flex-col items-center py-16 gap-6">
                <div className="h-24 w-24 rounded-full bg-green-500/20 flex items-center justify-center text-green-500 scale-110 animate-in zoom-in duration-500">
                  <CheckCircle2 className="h-16 w-16" />
                </div>
                <p className="text-2xl font-bold tracking-tight text-green-500">{statusMessage}</p>
              </div>
            )}

            {state === "error" && (
              <div className="flex flex-col items-center py-10 gap-6 text-center">
                <AlertCircle className="h-20 w-20 text-red-500" />
                <div className="space-y-1">
                   <p className="text-xl font-bold text-red-500">Ops!</p>
                   <p className="text-white/60">{statusMessage}</p>
                </div>
                <Button onClick={reset} variant="outline" className="w-full rounded-2xl bg-white/5 border-white/10 hover:bg-indigo-500 hover:text-white transition-all">Tentar de Novo</Button>
              </div>
            )}
          </div>

          <div className="p-6 bg-white/5 border-t border-white/5 flex items-center justify-center gap-2">
             <div className="h-1.5 w-1.5 rounded-full bg-indigo-500" />
             <span className="text-[10px] text-white/40 font-medium tracking-widest uppercase">Agentic Intelligence Engine V1.0</span>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}

