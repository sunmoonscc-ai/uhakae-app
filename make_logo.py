from PIL import Image

def add_white_bg(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    
    # Create full white background
    bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
    bg.alpha_composite(img)
    
    bg.save(output_path)

if __name__ == "__main__":
    add_white_bg("assets/images/logo_new.png", "assets/images/logo_dark.png")
