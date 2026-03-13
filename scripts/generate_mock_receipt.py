from PIL import Image, ImageDraw, ImageFont
import os

def generate_mock_receipt(output_path="mock_receipt.png"):
    # Cria uma imagem em branco simulando um papel impresso
    img = Image.new('RGB', (600, 800), color=(255, 255, 255))
    d = ImageDraw.Draw(img)
    
    try:
        # Tenta carregar uma fonte monoespaçada simples
        font = ImageFont.truetype("DejaVuSansMono.ttf", 20)
        title_font = ImageFont.truetype("DejaVuSansMono-Bold.ttf", 26)
    except IOError:
        font = ImageFont.load_default()
        title_font = ImageFont.load_default()
        
    y_text = 50
    
    # Cabeçalho da Nota Fiscal
    d.text((150, y_text), "NOTA FISCAL ELETRONICA", fill=(0, 0, 0), font=title_font)
    y_text += 50
    d.text((50, y_text), "FORNECEDOR: TECIDOS FINOS LTDA", fill=(0, 0, 0), font=font)
    y_text += 30
    d.text((50, y_text), "DATA: 12/03/2026", fill=(0, 0, 0), font=font)
    y_text += 50
    d.text((50, y_text), "-"*40, fill=(0, 0, 0), font=font)
    y_text += 30
    
    # Itens (Domínio Nicho)
    items = [
        "1x Rolo Tecido Linho Off-White - 50 Metros - R$ 1.500,00",
        "10x Espuma Assento D28 - R$ 500,00",
        "2x Kit Ferragens Articulador - R$ 300,00"
    ]
    
    d.text((50, y_text), "PRODUTOS:", fill=(0, 0, 0), font=title_font)
    y_text += 40
    for item in items:
        d.text((50, y_text), item, fill=(0, 0, 0), font=font)
        y_text += 30
        
    y_text += 30
    d.text((50, y_text), "-"*40, fill=(0, 0, 0), font=font)
    y_text += 30
    d.text((50, y_text), "TOTAL DA NOTA: R$ 2.300,00", fill=(0, 0, 0), font=title_font)
    
    img.save(output_path)
    print(f"✅ Mock receipt generated: {output_path}")

if __name__ == "__main__":
    current_dir = os.path.dirname(os.path.abspath(__file__))
    output = os.path.join(current_dir, "tests", "mock_receipt.png")
    generate_mock_receipt(output)
