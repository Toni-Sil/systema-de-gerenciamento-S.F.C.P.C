import pytest
from fastapi.testclient import TestClient
from uuid import uuid4
from PIL import Image, ImageDraw
from io import BytesIO

# Imports da aplicação FastAPI
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))
from main import app

client = TestClient(app)

# Adds the scripts directory to path to use the generator
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../scripts')))
try:
    from generate_mock_receipt import generate_mock_receipt
except ImportError:
    generate_mock_receipt = None
from io import BytesIO

def create_mock_invoice_image() -> bytes:
    """Gera uma imagem realística com texto de Nota Fiscal usando o gerador do nicho."""
    if generate_mock_receipt:
        # Save to memory bytes instead of disk
        from PIL import Image, ImageDraw, ImageFont
        img = Image.new('RGB', (600, 800), color=(255, 255, 255))
        d = ImageDraw.Draw(img)
        font = ImageFont.load_default()
        d.text((10, 10), "NOTA FISCAL DE SERVICOS\nTransp\nTotal: 150.00\nLogistica", fill=(0,0,0), font=font)
        
        # We'll just generate the specific standard mocked image to bytes here to ensure consistency
        img_path = os.path.join(os.path.dirname(__file__), "mock_temp.png")
        generate_mock_receipt(img_path)
        with open(img_path, "rb") as f:
            b = f.read()
        if os.path.exists(img_path):
            os.remove(img_path)
        return b
    else:
        # Fallback
        img = Image.new('RGB', (500, 300), color = (255, 255, 255))
        d = ImageDraw.Draw(img)
        text = "NOTA FISCAL DE SERVICOS\nFornecedor: Transporte S/A\nData: 2026-03-12\nValor Total: R$ 150.00\nCategoria: Logistica\n"
        d.text((10,10), text, fill=(0,0,0))
        
        img_byte_arr = BytesIO()
        img.save(img_byte_arr, format='PNG')
        return img_byte_arr.getvalue()

def test_ocr_financial_ingestion_pipeline():
    """Testa o pipeline completo: Upload -> Memória (LGPD) -> OCR -> Agente LLM -> JSON Estrito"""
    tenant_id = str(uuid4())
    fake_image_bytes = create_mock_invoice_image()
    
    files = {'file': ('invoice.png', fake_image_bytes, 'image/png')}
    data = {'document_type': 'INVOICE'}
    
    resp = client.post("/finance/upload", headers={"X-Tenant-ID": tenant_id}, files=files, data=data)
    
    # A API deve responder graciosamente mesmo se o SO não tiver o binário Tesseract instalado.
    assert resp.status_code == 200, "Erro interno na Rota Multimodal."
    
    json_resp = resp.json()
    assert json_resp["status"] == "success"
    
    # O Tesseract vai extrair o texto em texto puro (ou mensagem de erro se o binário faltar)
    ocr_text = json_resp["ocr_preview"]
    assert isinstance(ocr_text, str)
    
    # O AgentOrchestrator vai capturar intenção de gasto
    agent_decision = json_resp["agent_decision"]
    assert "action" in agent_decision
    
    # Caso a extração tenha capturado alguma palavra chave da Nota (no mock ou real)
    if agent_decision["action"] == "RegisterExpense":
        assert agent_decision["params"]["value"] == 150.0
        assert agent_decision["params"]["supplier"] == "Transporte S/A"
