import { useState, useRef, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Mic, MicOff, ImagePlus, FileText, Loader2, CheckCircle2, AlertCircle } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { api } from "@/lib/api";

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
};

type ProcessingState = "idle" | "recording" | "processing" | "success" | "error";

export function AIMovementInput({ onDataExtracted }: AIInputProps) {
  const { toast } = useToast();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [state, setState] = useState<ProcessingState>("idle");
  const [statusMessage, setStatusMessage] = useState("");
  const [transcript, setTranscript] = useState("");
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pdfInputRef = useRef<HTMLInputElement>(null);

  const reset = () => {
    setState("idle");
    setStatusMessage("");
    setTranscript("");
  };

  const startRecording = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream, { mimeType: "audio/webm" });
      mediaRecorderRef.current = mediaRecorder;
      chunksRef.current = [];
      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };
      mediaRecorder.onstop = async () => {
        stream.getTracks().forEach((t) => t.stop());
        const blob = new Blob(chunksRef.current, { type: "audio/webm" });
        await processVoice(blob);
      };
      mediaRecorder.start();
      setState("recording");
      setStatusMessage("Gravando... Descreva a movimentacao.");
      setDialogOpen(true);
    } catch {
      toast({
        title: "Erro ao acessar microfone",
        description: "Verifique as permissoes do navegador.",
        variant: "destructive",
      });
    }
  }, []);

  const stopRecording = useCallback(() => {
    mediaRecorderRef.current?.stop();
    setState("processing");
    setStatusMessage("Transcrevendo audio...");
  }, []);

  const processVoice = async (blob: Blob) => {
    try {
      const buffer = await blob.arrayBuffer();
      const base64 = btoa(
        new Uint8Array(buffer).reduce((s, b) => s + String.fromCharCode(b), "")
      );

      // Step 1: Transcribe via FastAPI
      const transcribeRes = await api.post("/ai/transcribe-audio", {
        audio: base64,
        mimeType: "audio/webm",
      });
      const text = transcribeRes.transcript;
      setTranscript(text);
      setStatusMessage("Extraindo dados com IA...");

      // Step 2: Extract movement data
      const extractRes = await api.post("/ai/process-movement", {
        type: "voice",
        content: text,
      });
      handleSuccess(extractRes.movement);
    } catch (e: any) {
      handleError(e.message || "Erro ao processar audio");
    }
  };

  const handleFileUpload = async (file: File, inputType: "image" | "pdf") => {
    setDialogOpen(true);
    setState("processing");
    setStatusMessage(`Analisando ${inputType === "pdf" ? "documento" : "imagem"} com IA...`);
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
      handleError(e.message || `Erro ao processar ${inputType}`);
    }
  };

  const handleSuccess = (movementData: MovementData) => {
    setState("success");
    setStatusMessage("Dados extraidos com sucesso!");
    onDataExtracted(movementData);
    setTimeout(() => {
      setDialogOpen(false);
      reset();
    }, 1500);
  };

  const handleError = (message: string) => {
    setState("error");
    setStatusMessage(message);
    toast({ title: "Erro no processamento", description: message, variant: "destructive" });
  };

  return (
    <>
      <div className="flex gap-2">
        <Button
          variant="outline"
          onClick={state === "recording" ? stopRecording : startRecording}
          className="gap-2"
          title="Registrar por voz"
        >
          {state === "recording" ? <MicOff className="h-4 w-4 text-red-500" /> : <Mic className="h-4 w-4" />}
          Voz
        </Button>

        <Button
          variant="outline"
          onClick={() => fileInputRef.current?.click()}
          className="gap-2"
          title="Registrar por imagem"
        >
          <ImagePlus className="h-4 w-4" />
          Imagem
        </Button>

        <Button
          variant="outline"
          onClick={() => pdfInputRef.current?.click()}
          className="gap-2"
          title="Registrar por PDF"
        >
          <FileText className="h-4 w-4" />
          PDF
        </Button>

        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
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
      </div>

      <Dialog
        open={dialogOpen}
        onOpenChange={(open) => {
          if (!open) {
            if (state === "recording") stopRecording();
            else { setDialogOpen(false); reset(); }
          }
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {state === "recording" ? "Gravando Audio"
                : state === "processing" ? "Processando com IA"
                : state === "success" ? "Sucesso!"
                : state === "error" ? "Erro"
                : "IA"}
            </DialogTitle>
          </DialogHeader>

          <div className="flex flex-col items-center gap-4 py-4">
            {state === "recording" && (
              <>
                <div className="h-16 w-16 rounded-full bg-red-100 flex items-center justify-center animate-pulse">
                  <Mic className="h-8 w-8 text-red-500" />
                </div>
                <p className="text-sm text-muted-foreground">{statusMessage}</p>
                <Button onClick={stopRecording} variant="destructive">Parar Gravacao</Button>
              </>
            )}
            {state === "processing" && (
              <>
                <Loader2 className="h-12 w-12 animate-spin text-primary" />
                <p className="text-sm text-muted-foreground">{statusMessage}</p>
                {transcript && (
                  <div className="text-xs bg-muted rounded p-3 w-full">
                    <p className="font-medium mb-1">Transcricao:</p>
                    <p>&ldquo;{transcript}&rdquo;</p>
                  </div>
                )}
              </>
            )}
            {state === "success" && (
              <>
                <CheckCircle2 className="h-12 w-12 text-green-500" />
                <p className="text-sm text-green-600">{statusMessage}</p>
              </>
            )}
            {state === "error" && (
              <>
                <AlertCircle className="h-12 w-12 text-red-500" />
                <p className="text-sm text-red-600">{statusMessage}</p>
                <Button onClick={reset} variant="outline">Tentar novamente</Button>
              </>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
