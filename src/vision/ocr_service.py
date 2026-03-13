import pytesseract
from PIL import Image
from io import BytesIO

class OCRService:
    """Serviço responsável pela Visão Computacional de Documentos (OCR)."""
    
    @staticmethod
    def extract_text(file_bytes: bytes) -> str:
        """
        Recebe os bytes efêmeros de um arquivo na memória (ex: NF, Recibo),
        e extrai o texto bruto usando Tesseract sem gravar no disco (Compliance LGPD).
        """
        try:
            image = Image.open(BytesIO(file_bytes))
            
            # Tenta utilizar o pack Português se instalado no host (fallback automático para ENG do PyTesseract)
            try:
                text = pytesseract.image_to_string(image, lang='por')
            except:
                text = pytesseract.image_to_string(image)
                
            return text.strip()
            
        except Exception as e:
            return f"[ERROR OCR]: Incapaz de ler imagem - {str(e)}"
